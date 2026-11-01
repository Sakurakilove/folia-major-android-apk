import '../motion/color_value.dart';
import '../motion/scalar_value.dart';
import 'glow_ramp_spec.dart';

// Each source grapheme owns a ramp, not a ticker or a separately shaped text paragraph on every frame.
class GlowGlyphMotion {
  GlowGlyphMotion(this.spec, this.color);
  final GlowRampSpec spec;
  MotionRgba color;
  final shadowAmount = MotionScalarValue(0, variantTarget: 'none'),
      filterAmount = MotionScalarValue(0, variantTarget: 'none'),
      opacity = MotionScalarValue(1);
  bool dropShadow = false;
  double get innerRadius => dropShadow
      ? spec.inner * .4 * filterAmount.value
      : _sanitize(spec.inner * shadowAmount.value);
  double get outerRadius => dropShadow
      ? spec.outer * .4 * filterAmount.value
      : _sanitize(spec.outer * shadowAmount.value);
  double get shadowAlpha => dropShadow
      ? opacity.value
      : _sanitize(color.alpha * shadowAmount.value).clamp(0.0, 1.0);
  bool get isAnimating =>
      shadowAmount.isAnimating ||
      filterAmount.isAnimating ||
      opacity.isAnimating;
  static double _sanitize(double n) => (n * 100000).round() / 100000;

  void transition(
    String state,
    double now, {
    required bool quantized,
    required String revealMode,
  }) {
    dropShadow = quantized;
    if (state == 'waiting') {
      if (quantized) {
        opacity.jump(0, now);
        filterAmount.jump(0, now);
        shadowAmount.jump(0, now);
      } else {
        opacity.jump(1, now);
        filterAmount.jump(0, now);
        shadowAmount.animateVariant(
          'textShadow',
          0,
          const {},
          now,
          identity: 'none',
        );
      }
      return;
    }
    if (state == 'active') {
      if (quantized) {
        filterAmount.animateVariant(
          'filter',
          spec.peaks,
          spec.transition,
          now,
          css: true,
          identity: 'drop:${spec.inner}:${spec.outer}:$color:${spec.peaks}',
        );
        opacity.animateVariant(
          'opacity',
          spec.peaks,
          spec.transition,
          now,
          css: true,
        );
      } else {
        // Explicit first zero keyframe is kept, even when interrupting a previous ramp.
        shadowAmount.animateVariant(
          'textShadow',
          spec.peaks,
          spec.transition,
          now,
          identity: 'shadow:${spec.inner}:${spec.outer}:$color:${spec.peaks}',
        );
      }
      return;
    }
    final duration = revealMode == 'instant'
        ? .12
        : revealMode == 'fast'
        ? .22
        : .9;
    final transition = {'duration': duration, 'ease': 'easeOut'};
    if (quantized) {
      filterAmount.animateVariant(
        'filter',
        0,
        transition,
        now,
        css: true,
        identity: 'drop:0:0:$color',
      );
      opacity.animateVariant('opacity', 0, transition, now, css: true);
    } else {
      shadowAmount.animateVariant(
        'textShadow',
        0,
        transition,
        now,
        identity: 'none',
      );
    }
  }

  void advance(double now) {
    shadowAmount.advance(now);
    filterAmount.advance(now);
    opacity.advance(now);
  }
}
