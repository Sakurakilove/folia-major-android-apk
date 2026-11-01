package top.izuna.foliamajor.next.lyrics

import android.icu.lang.UCharacter
import android.icu.text.BreakIterator
import android.icu.util.ULocale
import android.icu.util.VersionInfo
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

// Document preparation only: native ICU returns compact UTF-16 end/status pairs, never one platform message per rendered word or frame.
class NativeWordSegmentation(messenger: BinaryMessenger) : AutoCloseable {
    private val channel = MethodChannel(messenger, "top.izuna.folia/word-segmentation")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val pending = LinkedHashMap<Int, MethodChannel.Result>()
    private val iterators = LinkedHashMap<String, BreakIterator>()
    private var sequence = 0
    @Volatile private var closed = false

    init { channel.setMethodCallHandler(::handle) }

    private fun info() = mapOf(
        "icuVersion" to VersionInfo.ICU_VERSION.toString(),
        "unicodeVersion" to UCharacter.getUnicodeVersion().toString(),
        "defaultLocale" to ULocale.getDefault().toLanguageTag(),
    )

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (closed) { result.error("closed", "Word preparation host closed", null); return }
        if (call.method == "getInfo") { result.success(info()); return }
        if (call.method != "segmentBatch") { result.notImplemented(); return }
        val texts = call.argument<List<*>>("texts")
        val localeTag = call.argument<String>("locale")
        if (texts == null || texts.size > 128 || texts.any { it !is String }
            || (texts.size > 1 && texts.sumOf { (it as String).length.toLong() } > 65_536)
            || localeTag.isNullOrEmpty() || localeTag.length > 128) {
            result.error("arguments", "Expected a bounded text batch and an explicit locale", null); return
        }
        if (pending.size >= 8) { result.error("busy", "Word preparation queue full", null); return }
        val id = sequence++
        pending[id] = result
        worker.execute {
            try {
                val locale = ULocale.Builder().setLanguageTag(localeTag).build()
                val iterator = iterators.getOrPut(localeTag) {
                    if (iterators.size >= 4) iterators.remove(iterators.keys.first())
                    BreakIterator.getWordInstance(locale)
                }
                val segments = texts.map { text ->
                    if (closed || Thread.currentThread().isInterrupted) throw InterruptedException("Word preparation cancelled")
                    cut(iterator, text as String)
                }
                val response = info() + mapOf("locale" to locale.toLanguageTag(), "segments" to segments)
                main.post { pending.remove(id)?.success(response) }
            } catch (failure: Exception) {
                main.post { pending.remove(id)?.error("segmentation", failure.message, mapOf("type" to failure.javaClass.name)) }
            }
        }
    }

    private fun cut(iterator: BreakIterator, text: String): IntArray {
        var pairs = IntArray(minOf(32, maxOf(4, text.length)) * 2)
        var used = 0
        try {
            iterator.setText(text)
            iterator.first()
            var end = iterator.next()
            while (end != BreakIterator.DONE) {
                if (used + 2 > pairs.size) pairs = pairs.copyOf(pairs.size * 2)
                pairs[used++] = end
                pairs[used++] = iterator.ruleStatus
                end = iterator.next()
            }
            return pairs.copyOf(used)
        } finally {
            // Do not retain the last song's lyrics inside a cached native iterator.
            iterator.setText("")
        }
    }

    override fun close() {
        if (closed) return
        closed = true
        channel.setMethodCallHandler(null)
        worker.shutdownNow()
        pending.values.forEach { it.error("closed", "Word preparation host closed", null) }
        pending.clear()
    }
}
