import 'dart:math' as math;

// Source twenty-four-step fit keeps all four corners of the tilted artist poster on screen with the original margin.
({double scale, double offsetY}) posterSafeArea(
  double width,
  double height,
  double deg,
) {
  if (deg.abs() < .01 || width <= 0 || height <= 0) {
    return (scale: 1, offsetY: 0);
  }
  final radians = deg * math.pi / 180,
      cos = math.cos(radians),
      sin = math.sin(radians),
      half = height / 2;
  ({double low, double high}) rangeFor(double scale) {
    var low = double.negativeInfinity, high = double.infinity;
    void bound(double coefficient, double constant, double min, double max) {
      if (coefficient.abs() < 1e-9) {
        if (constant < min || constant > max) low = double.infinity;
        return;
      }
      final a = (min - constant) / coefficient,
          b = (max - constant) / coefficient;
      low = math.max(low, math.min(a, b));
      high = math.min(high, math.max(a, b));
    }

    for (final rx in [-scale * width, 0.0]) {
      for (final extra in [0.0, scale * height]) {
        final base = extra - half;
        bound(-sin, width + rx * cos - base * sin, 14, double.infinity);
        bound(cos, half + rx * sin + base * cos, 14, height - 14);
      }
    }
    return (low: low, high: high);
  }

  var lo = .5, hi = 1.0;
  if (rangeFor(1).low <= rangeFor(1).high) {
    lo = 1;
  } else {
    for (var i = 0; i < 24; i++) {
      final mid = (lo + hi) / 2, range = rangeFor(mid);
      if (range.low <= range.high) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
  }
  final range = rangeFor(lo),
      centered = (1 - lo) * height / 2,
      offset = range.low.isFinite
          ? math.min(math.max(centered, range.low), range.high)
          : centered;
  return (scale: lo, offsetY: offset);
}
