package top.izuna.foliamajor.next.artwork

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

// Sparse request/cancel messages return native descriptor tickets. IO/closing blocked sockets stays off the Android main thread.
class NativeArtworkAccess(context: Context, messenger: BinaryMessenger) : AutoCloseable {
    private val channel = MethodChannel(messenger, "top.izuna.folia/artwork")
    private val main = Handler(Looper.getMainLooper())
    private val workers = ThreadPoolExecutor(2, 2, 0, TimeUnit.MILLISECONDS, ArrayBlockingQueue<Runnable>(256))
    private val cleanup = Executors.newSingleThreadExecutor()
    private val source = ArtworkSource(context.applicationContext)
    private data class Pending(val read: ArtworkReadJob, val result: MethodChannel.Result)
    private val jobs = ConcurrentHashMap<Int, Pending>()
    private var scope = 0L
    @Volatile private var closed = false
    init { channel.setMethodCallHandler(::handle) }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (closed) { result.error("closed", "Artwork host closed", null); return }
        val id = call.argument<Number>("id")?.toInt()
        if (id == null) { result.error("arguments", "Artwork request id required", null); return }
        if (call.method == "cancel") {
            jobs.remove(id)?.let { it.read.cancel(cleanup); it.result.error("cancelled", "Artwork request cancelled", null) }
            result.success(null); return
        }
        if (call.method != "open") { result.notImplemented(); return }
        val url = call.argument<String>("url")
        val rawHeaders = call.argument<Map<*, *>>("headers") ?: emptyMap<Any, Any>()
        if (url.isNullOrEmpty() || rawHeaders.any { it.key !is String || it.value !is String }) {
            result.error("arguments", "Expected an artwork source and string headers", null); return
        }
        if (jobs.containsKey(id) || jobs.size >= 258) { result.error("busy", "Artwork request queue full", null); return }
        if (scope == 0L) scope = NativeArtworkDescriptors.createScope()
        if (scope == 0L) { result.error("memory", "Artwork host allocation failed", null); return }
        val owner = scope
        val headers = rawHeaders.entries.associate { it.key as String to it.value as String }
        val pending = Pending(ArtworkReadJob(), result); jobs[id] = pending
        try {
            workers.execute {
                var ticket = 0L
                try {
                    source.materialize(url, headers, pending.read).use { fd ->
                        pending.read.check()
                        ticket = NativeArtworkDescriptors.registerFd(owner, fd.fd)
                        if (ticket == 0L) throw java.io.IOException("Artwork descriptor allocation failed")
                    }
                    val ready = ticket
                    main.post {
                        if (closed || pending.read.cancelled.get() || jobs[id] !== pending) {
                            NativeArtworkDescriptors.releaseTicket(ready)
                        } else {
                            jobs.remove(id)
                            result.success(mapOf("ticket" to ready))
                        }
                    }
                } catch (failure: Exception) {
                    if (ticket != 0L) NativeArtworkDescriptors.releaseTicket(ticket)
                    main.post {
                        if (jobs.remove(id, pending)) result.error(
                            if (pending.read.cancelled.get()) "cancelled" else "artwork",
                            "Artwork source could not be prepared", mapOf("type" to failure.javaClass.name),
                        )
                    }
                }
            }
        } catch (_: RejectedExecutionException) {
            jobs.remove(id); result.error("busy", "Artwork request queue full", null)
        }
    }
    override fun close() {
        if (closed) return
        closed = true; channel.setMethodCallHandler(null)
        for ((_, pending) in jobs) {
            pending.read.cancel(cleanup); pending.result.error("closed", "Artwork host closed", null)
        }
        jobs.clear(); workers.shutdownNow()
        if (scope != 0L) NativeArtworkDescriptors.releaseScope(scope)
        scope = 0; cleanup.shutdown()
    }
}
