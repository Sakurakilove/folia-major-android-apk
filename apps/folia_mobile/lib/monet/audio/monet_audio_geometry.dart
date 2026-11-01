import 'dart:math' as math;
import 'dart:typed_data';

import '../../audio/analysis/spectrum_snapshot.dart';
import 'monet_audio_profile.dart';

// Original 72-bar/curve geometry and time phases; the fixed buffers are reused on every frame.
class MonetAudioGeometry {
  final profile = MonetAudioProfile();
  final x = Float64List(monetAudioBarCount),
      y = Float64List(monetAudioBarCount);
  double barWidth = 0;
  void update({
    required SpectrumSnapshot audio,
    required double width,
    required double height,
    required double nowMs,
    required bool line,
    bool staticMode = false,
  }) {
    final values = staticMode ? null : profile.update(audio);
    final energy = (audio.power / 255).clamp(.08, 1.0),
        gap = width / monetAudioBarCount;
    barWidth = math.max(1.35, gap * .34);
    for (var i = 0; i < monetAudioBarCount; i++) {
      final index = i / (monetAudioBarCount - 1),
          envelope = math.sin(index * math.pi);
      x[i] = line ? index * width : i * gap + gap * .14;
      if (staticMode) {
        final value = .12 + (math.sin(i * .35) * .5 + .5) * .42;
        y[i] = line
            ? height - height * value * envelope
            : height - height * (.02 + value * .8 * envelope);
      } else if (line) {
        final wave =
            math.sin(i * .24 + nowMs * .004) * .08 +
            math.sin(i * .68 + nowMs * .0028) * .05;
        final amplitude = energy * .04 + values![i] * .8 + wave * .04;
        y[i] = height - math.max(0, height * amplitude * envelope);
      } else {
        final pulse = math.sin(i * .45 + nowMs * .006) * .5 + .5;
        final barHeight =
            height *
            (.02 + (energy * .04 + values![i] * .82 + pulse * .02) * envelope);
        y[i] = height - barHeight;
      }
    }
  }
}
