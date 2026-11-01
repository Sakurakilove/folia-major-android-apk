package top.izuna.foliamajor.next.analysis

import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MimeTypes
import java.nio.ByteBuffer

// Only control edges use Flutter channels. PCM stays in native memory and visual snapshots use FFI.
object NativeSpectrum {
    private val loaded = try { System.loadLibrary("folia_analysis"); true }
        catch (failure: LinkageError) { Log.e("FoliaAnalysis", "Native analysis library unavailable", failure); false }
    @Volatile var enabled = false
        private set
    @Volatile private var supported = false

    fun requestEnabled(wanted: Boolean) {
        val next = loaded && wanted
        if (enabled == next) return
        enabled = next
        enabledNative(next)
    }

    fun configure(format: Format): Int {
        val encoding = when (format.pcmEncoding) {
            C.ENCODING_PCM_8BIT -> 1
            C.ENCODING_PCM_16BIT -> 2
            C.ENCODING_PCM_16BIT_BIG_ENDIAN -> 3
            C.ENCODING_PCM_24BIT -> 4
            C.ENCODING_PCM_24BIT_BIG_ENDIAN -> 5
            C.ENCODING_PCM_32BIT -> 6
            C.ENCODING_PCM_32BIT_BIG_ENDIAN -> 7
            C.ENCODING_PCM_FLOAT -> 8
            C.ENCODING_PCM_FLOAT_BIG_ENDIAN -> 9
            C.ENCODING_PCM_DOUBLE -> 10
            C.ENCODING_PCM_DOUBLE_BIG_ENDIAN -> 11
            else -> 0
        }
        val sampleBytes = when (encoding) { 1 -> 1; 2, 3 -> 2; 4, 5 -> 3; 6, 7, 8, 9 -> 4; 10, 11 -> 8; else -> 0 }
        supported = loaded && configureNative(format.sampleRate, format.channelCount,
            if (format.sampleMimeType == MimeTypes.AUDIO_RAW) encoding else 0)
        if (!supported) Log.w("FoliaAnalysis", "PCM analysis unavailable for the current sink format; audio is unchanged")
        return if (supported) sampleBytes * format.channelCount else 0
    }

    fun reset() { if (loaded) resetNative() }
    fun invalidateClock() { if (loaded) invalidateClockNative() }
    fun gain(value: Float) { if (loaded) gainNative(value) }
    fun offer(buffer: ByteBuffer, start: Int, end: Int, ptsUs: Long, gain: Float,
              headUs: Long, headNs: Long, speed: Float) {
        if (supported) offerNative(buffer, start, end, ptsUs, gain, headUs, headNs, speed)
    }
    private external fun configureNative(rate: Int, channels: Int, encoding: Int): Boolean
    private external fun enabledNative(enabled: Boolean)
    private external fun resetNative()
    private external fun gainNative(gain: Float)
    private external fun invalidateClockNative()
    private external fun offerNative(buffer: ByteBuffer, start: Int, end: Int, ptsUs: Long,
                                     gain: Float, headUs: Long, headNs: Long, speed: Float)
}
