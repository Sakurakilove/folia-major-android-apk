package top.izuna.foliamajor.next.artwork

import android.content.Context
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File
import java.io.InputStream
import java.io.InterruptedIOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executor
import java.util.concurrent.atomic.AtomicBoolean
import java.util.zip.GZIPInputStream
import java.util.zip.InflaterInputStream

// Native IO materializes a seekable private file, then unlinks it after opening: ContentProvider pipes/offset assets never escape as unsafe mmap paths.
class ArtworkReadJob {
    val cancelled = AtomicBoolean(false)
    private val gate = Any()
    private val closers = ArrayList<() -> Unit>()
    fun check() { if (cancelled.get() || Thread.currentThread().isInterrupted) throw InterruptedIOException("Artwork cancelled") }
    fun own(close: () -> Unit) {
        synchronized(gate) {
            if (cancelled.get()) { runCatching(close); throw InterruptedIOException("Artwork cancelled") }
            closers.add(close)
        }
    }
    fun cancel(cleanup: Executor) {
        if (!cancelled.compareAndSet(false, true)) return
        val actions = synchronized(gate) { closers.toList().also { closers.clear() } }
        if (actions.isNotEmpty()) cleanup.execute { actions.forEach { runCatching(it) } }
    }
    fun clear() { synchronized(gate) { closers.clear() } }
    fun closeOnWorker() {
        val actions = synchronized(gate) { closers.toList().also { closers.clear() } }
        actions.forEach { runCatching(it) }
    }
}

class ArtworkSource(private val context: Context) {
    companion object {
        private val temporaryGate = Any()
        private var cleaned = false
    }
    private fun temporaryFile(): File = synchronized(temporaryGate) {
        // Clean once per process before any host can create a new live fallback file.
        if (!cleaned) {
            context.cacheDir.listFiles { file -> file.name.startsWith("folia-wall-artwork-") }?.forEach { it.delete() }
            cleaned = true
        }
        File.createTempFile("folia-wall-artwork-", ".img", context.cacheDir)
    }
    fun materialize(source: String, headers: Map<String, String>, job: ArtworkReadJob): ParcelFileDescriptor {
        job.check()
        val memoryFd = NativeArtworkDescriptors.createMemoryFile()
        val memory = if (memoryFd >= 0) ParcelFileDescriptor.adoptFd(memoryFd) else null
        val file = if (memory == null) temporaryFile() else null
        var completed = false
        var readComplete = false
        try {
            open(source, headers, job).use { input ->
                job.own { input.close() }
                val sink = if (memory != null) ParcelFileDescriptor.AutoCloseOutputStream(ParcelFileDescriptor.dup(memory.fileDescriptor))
                    else file!!.outputStream()
                sink.buffered(32768).use { output ->
                    val buffer = ByteArray(32768)
                    while (true) {
                        job.check()
                        val read = input.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                    }
                }
            }
            readComplete = true
            job.check()
            val fd = memory ?: ParcelFileDescriptor.open(file!!, ParcelFileDescriptor.MODE_READ_ONLY)
            if (fd.statSize == 0L) { if (memory == null) fd.close(); throw java.io.IOException("Empty artwork") }
            completed = true
            return fd
        } finally {
            if (!completed) memory?.close()
            file?.delete()
            if (readComplete) job.clear() else job.closeOnWorker()
        }
    }

    private fun open(source: String, headers: Map<String, String>, job: ArtworkReadJob): InputStream {
        val uri = Uri.parse(source)
        return when (uri.scheme?.lowercase()) {
            "http", "https" -> network(source, headers, job)
            "content", "file", "android.resource" -> context.contentResolver.openInputStream(uri)
                ?: throw java.io.IOException("Artwork source unavailable")
            else -> throw java.io.IOException("Artwork source needs an asset resolver")
        }
    }

    private fun network(source: String, headers: Map<String, String>, job: ArtworkReadJob): InputStream {
        ArtworkHttpCache.ensure(context)
        var address = source
        var credentialsAllowed = true
        for (hop in 0..20) {
            job.check()
            val url = URL(address)
            if (url.protocol != "http" && url.protocol != "https") throw java.io.IOException("Unsupported artwork redirect")
            val connection = url.openConnection() as HttpURLConnection
            job.own { connection.disconnect() }
            connection.connectTimeout = 15000; connection.readTimeout = 15000
            connection.useCaches = true
            connection.instanceFollowRedirects = false
            for ((key, value) in headers) {
                if (!credentialsAllowed && (key.equals("Authorization", true) || key.equals("Proxy-Authorization", true)
                    || key.equals("Cookie", true) || key.equals("Cookie2", true))) continue
                connection.setRequestProperty(key, value)
            }
            val code = connection.responseCode
            if (code in listOf(301, 302, 303, 307, 308)) {
                val location = connection.getHeaderField("Location") ?: throw java.io.IOException("Artwork redirect missing location")
                val next = NativeArtworkUrls.resolve(address, location)
                    ?: throw java.io.IOException("Invalid artwork redirect")
                val nextUrl = URL(next)
                if (nextUrl.protocol != url.protocol || nextUrl.host != url.host || nextUrl.port != url.port) credentialsAllowed = false
                address = next; connection.disconnect(); continue
            }
            if (code !in 200..299) { connection.disconnect(); throw java.io.IOException("Artwork HTTP status $code") }
            val input = connection.inputStream
            return when (connection.contentEncoding?.lowercase()) {
                "gzip" -> GZIPInputStream(input)
                "deflate" -> InflaterInputStream(input)
                else -> input
            }
        }
        throw java.io.IOException("Artwork redirect limit exceeded")
    }

}
