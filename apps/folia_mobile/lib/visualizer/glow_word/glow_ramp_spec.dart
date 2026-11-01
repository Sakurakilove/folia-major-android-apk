import 'dart:math' as math;

// Typed original wordGlow.ts active ramp, including actual syllable timing and source truthy-duration fallback.
class GlowRampSpec {
  const GlowRampSpec(
    this.inner,
    this.outer,
    this.peaks,
    this.times,
    this.duration,
    this.delay,
    this.ease,
  );
  final double inner, outer, duration, delay;
  final List<double> peaks, times;
  final String ease;
  Map<String, dynamic> get transition => {
    'duration': duration,
    'delay': delay,
    'times': times,
    'ease': ease,
  };
}

double _or(double? value, double fallback) =>
    value == null || value == 0 || value.isNaN ? fallback : value;
GlowRampSpec resolveGlowRamp({
  double? duration,
  int? index,
  int? total,
  double? charStartTime,
  double? charEndTime,
  double? wordStartTime,
  String? revealMode,
}) {
  if (revealMode == 'instant') {
    return GlowRampSpec(
      14,
      24,
      const [0, 1, 0],
      const [0, .35, 1],
      math.min(_or(duration, .08), .12),
      0,
      'easeOut',
    );
  }
  if (revealMode == 'fast') {
    return GlowRampSpec(
      18,
      32,
      const [0, 1, 0],
      const [0, .4, 1],
      math.min(math.max(_or(duration, .12), .12), .2),
      0,
      'easeInOut',
    );
  }
  if (total != null && total > 1) {
    final timed =
        charStartTime != null && charEndTime != null && wordStartTime != null;
    final singleDuration = (duration ?? 0) / total;
    final charDuration = timed
        ? math.max(charEndTime - charStartTime, .001)
        : singleDuration;
    final charDelay = timed
        ? math.max(0.0, charStartTime - wordStartTime)
        : singleDuration * (index ?? 0);
    return GlowRampSpec(
      20,
      40,
      const [0, 1, 0],
      const [0, .3, 1],
      charDuration * 6,
      charDelay,
      'easeInOut',
    );
  }
  return GlowRampSpec(
    20,
    40,
    const [0, 1, 1],
    const [0, .9, 1],
    _or(duration, .1),
    0,
    'easeInOut',
  );
}
