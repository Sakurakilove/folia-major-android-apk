package top.izuna.foliamajor.next.analysis

import android.content.Context
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.audio.AudioSink

// Native PCM analysis is attached beside the existing output, with no second player or output format coercion.
class AnalysisRenderersFactory(context: Context) : DefaultRenderersFactory(context) {
    init { setEnableAudioFloatOutput(true) }
    override fun buildAudioSink(context: Context, enableFloatOutput: Boolean, enableAudioTrackPlaybackParams: Boolean): AudioSink? =
        super.buildAudioSink(context, enableFloatOutput, enableAudioTrackPlaybackParams)?.let(::AnalysisAudioSink)
}
