package top.izuna.foliamajor.next.analysis

import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.ForwardingAudioSink
import java.nio.ByteBuffer

// Passive tap: capture only consumed PCM, preserve positions, timestamps, formats and the delegate's backpressure.
class AnalysisAudioSink(delegate: AudioSink) : ForwardingAudioSink(delegate) {
    private var sampleRate = 0
    private var frameBytes = 0
    private var volume = 1f
    private var currentBuffer: ByteBuffer? = null
    private var basePosition = 0

    override fun configure(config: AudioSink.AudioSinkConfig) {
        super.configure(config)
        frameBytes = NativeSpectrum.configure(config.format)
        sampleRate = config.format.sampleRate
        currentBuffer = null
    }

    override fun handleBuffer(buffer: ByteBuffer, presentationTimeUs: Long, encodedAccessUnitCount: Int): Boolean {
        if (currentBuffer !== buffer) { currentBuffer = buffer; basePosition = buffer.position() }
        val before = buffer.position()
        val consumed = super.handleBuffer(buffer, presentationTimeUs, encodedAccessUnitCount)
        val after = buffer.position()
        if (frameBytes > 0 && sampleRate > 0 && buffer.isDirect) {
            val offsetUs = (before - basePosition).toLong() / frameBytes * 1_000_000L / sampleRate
            val headUs = super.getCurrentPositionUs(false)
            NativeSpectrum.offer(buffer, before, after, presentationTimeUs + offsetUs, volume,
                headUs, System.nanoTime(), super.getPlaybackParameters().speed)
        }
        if (consumed) currentBuffer = null
        return consumed
    }

    override fun setVolume(volume: Float) { super.setVolume(volume); this.volume = volume; NativeSpectrum.gain(volume) }
    override fun play() { NativeSpectrum.invalidateClock(); super.play() }
    override fun pause() { NativeSpectrum.invalidateClock(); super.pause() }
    override fun handleDiscontinuity() { NativeSpectrum.reset(); currentBuffer = null; super.handleDiscontinuity() }
    override fun flush() { NativeSpectrum.reset(); currentBuffer = null; super.flush() }
    override fun reset() { NativeSpectrum.reset(); currentBuffer = null; super.reset() }
}
