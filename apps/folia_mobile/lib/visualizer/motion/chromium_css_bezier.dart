// Chromium 154 gfx::CubicBezier solver with endpoint-gradient extrapolation: 11 spline samples, four Newton iterations and the original 1e-7 stopping criterion. Mathematical exactness alone does not reproduce its serialized CSS samples.
class ChromiumCssBezier {
  ChromiumCssBezier(double x1, double y1, double x2, double y2) {
    cx = 3 * x1;
    bx = 3 * (x2 - x1) - cx;
    ax = 1 - cx - bx;
    cy = _finite(3 * y1);
    by = _finite(3 * (y2 - y1) - cy);
    ay = _finite(1 - cy - by);
    startGradient = x1 > 0
        ? y1 / x1
        : y1 == 0 && x2 > 0
        ? y2 / x2
        : y1 == 0 && y2 == 0
        ? 1
        : 0;
    endGradient = x2 < 1
        ? (y2 - 1) / (x2 - 1)
        : y2 == 1 && x1 < 1
        ? (y1 - 1) / (x1 - 1)
        : y2 == 1 && y1 == 1
        ? 1
        : 0;
    samples = List.generate(11, (i) => _x(i * (1.0 / 10)), growable: false);
  }
  late final double ax, bx, cx, ay, by, cy;
  late final double startGradient, endGradient;
  late final List<double> samples;
  double _x(double t) => ((ax * t + bx) * t + cx) * t;
  double _y(double t) => _finite(((ay * t + by) * t + cy) * t);
  static double _finite(double value) => value.isInfinite
      ? value.isNegative
            ? -double.maxFinite
            : double.maxFinite
      : value;
  double _derivative(double t) => (3 * ax * t + 2 * bx) * t + cx;
  double sample(double x) {
    final result = x < 0
        ? startGradient * x
        : x > 1
        ? 1 + endGradient * (x - 1)
        : sampleUnit(x);
    return result.isInfinite
        ? result.isNegative
              ? -double.maxFinite
              : double.maxFinite
        : result;
  }

  double sampleUnit(double x) {
    assert(x >= 0 && x <= 1);
    var low = 0.0, high = 1.0, t = x, error = 0.0;
    for (var i = 1; i < 11; i++) {
      if (x <= samples[i]) {
        high = (1.0 / 10) * i;
        low = high - (1.0 / 10);
        t =
            low +
            (high - low) * (x - samples[i - 1]) / (samples[i] - samples[i - 1]);
        break;
      }
    }
    for (var i = 0; i < 4; i++) {
      error = _x(t) - x;
      if (error.abs() < 1e-7) return _y(t);
      final derivative = _derivative(t);
      if (derivative.abs() < 1e-7) break;
      t -= error / derivative;
    }
    if (error.abs() < 1e-7) return _y(t);
    while (low < high) {
      final sample = _x(t);
      if ((sample - x).abs() < 1e-7) return _y(t);
      if (x > sample) {
        low = t;
      } else {
        high = t;
      }
      t = (high + low) * .5;
    }
    return _y(t);
  }
}
