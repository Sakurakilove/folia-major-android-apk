package top.izuna.foliamajor.next

import android.content.*
import android.net.Uri
import android.os.IBinder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

// Native URI access and media ownership are independent of Flutter's frame loop.
class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private var service: PlaybackService? = null
    private var sink: EventChannel.EventSink? = null
    private var picker: MethodChannel.Result? = null
    private val waiting = ArrayDeque<() -> Unit>()
    private var bound = false
    private var visible = false
    private fun attachEvents() { service?.listen(if (visible && sink != null) { event -> sink?.success(event) } else null) }
    override fun onStart() { super.onStart(); visible = true; attachEvents() }
    override fun onStop() { visible = false; attachEvents(); super.onStop() }
    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            service = (binder as PlaybackService.LocalBinder).service
            attachEvents()
            while (waiting.isNotEmpty()) waiting.removeFirst().invoke()
        }
        override fun onServiceDisconnected(name: ComponentName?) { service = null }
    }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        bound = bindService(Intent(this, PlaybackService::class.java), connection, BIND_AUTO_CREATE)
        EventChannel(engine.dartExecutor.binaryMessenger, "top.izuna.folia/playback").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, events: EventChannel.EventSink) { sink = events; attachEvents() }
            override fun onCancel(args: Any?) { sink = null; service?.listen(null) }
        })
        MethodChannel(engine.dartExecutor.binaryMessenger, "top.izuna.folia/native").setMethodCallHandler { call, result ->
            when (call.method) {
                "getClock" -> result.success(android.os.SystemClock.elapsedRealtimeNanos() / 1_000_000.0)
                "loadLibrary", "saveLibrary" -> io.execute {
                    try {
                        val value = if (call.method == "loadLibrary") LibraryStore.read(this) else { LibraryStore.write(this, call.arguments as List<*>); null }
                        runOnUiThread { result.success(value) }
                    } catch (failure: Exception) { runOnUiThread { result.error("library", failure.message, null) } }
                }
                "pickAudio", "pickLyrics" -> {
                    if (picker != null) { result.error("busy", "A document picker is already open", null); return@setMethodCallHandler }
                    picker = result
                    val audio = call.method == "pickAudio"
                    try { startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE); type = if (audio) "audio/*" else "*/*"
                        putExtra(Intent.EXTRA_ALLOW_MULTIPLE, audio)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    }, if (audio) 101 else 102) } catch (failure: Exception) { picker = null; result.error("picker", failure.message, null) }
                }
                "play", "pause", "resume", "seek", "setQueue" -> {
                    val action = {
                        try {
                            if (call.method == "play" || call.method == "resume") startService(Intent(this, PlaybackService::class.java))
                            service!!.command(call.method, call.arguments as? Map<*, *>); result.success(null)
                        } catch (failure: Exception) { result.error("playback", failure.message, null) }
                    }
                    if (service != null) action() else if (waiting.size < 32) waiting.add(action) else result.error("busy", "Media service unavailable", null)
                }
                else -> result.notImplemented()
            }
        }
    }
    @Deprecated("Document picker callback bridges the Android system UI")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 101 && requestCode != 102) return
        val result = picker ?: return
        picker = null
        if (resultCode != RESULT_OK || data == null) { result.success(if (requestCode == 101) emptyList<Any>() else null); return }
        val uris = if (data.clipData != null) (0 until data.clipData!!.itemCount).map { data.clipData!!.getItemAt(it).uri } else listOfNotNull(data.data)
        for (uri in uris) try { contentResolver.takePersistableUriPermission(uri, data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION) } catch (_: SecurityException) { /* Provider may grant session-only access. */ }
        io.execute {
            try {
                val answer: Any? = if (requestCode == 101) uris.map { DocumentImport.audio(this, it) }
                    else uris.firstOrNull()?.let { mapOf("text" to DocumentImport.lyrics(this, it)) }
                runOnUiThread { result.success(answer) }
            } catch (failure: Exception) { runOnUiThread { result.error("document", failure.message, null) } }
        }
    }
    override fun onDestroy() {
        service?.listen(null); service = null
        if (bound) unbindService(connection)
        bound = false; sink = null
        picker?.error("closed", "Document host closed", null); picker = null
        waiting.clear(); io.shutdown(); super.onDestroy()
    }
}
