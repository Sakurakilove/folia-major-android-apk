// Motion's JS cubic subdivision is deliberately separate from compositor CSS cubic evaluation (Motion MIT attribution in assets).
double _polynomial(double t, double a, double b) =>
    (((1 - 3 * b + 3 * a) * t + (3 * b - 6 * a)) * t + 3 * a) * t;
double _bezier(
  double x1,
  double y1,
  double x2,
  double y2,
  double progress,
  int iterations,
  double precision,
) {
  if (progress == 0 || progress == 1 || x1 == y1 && x2 == y2) return progress;
  double low = 0, high = 1, current = 0;
  for (var i = 0; i < iterations; i++) {
    current = low + (high - low) / 2;
    final difference = _polynomial(current, x1, x2) - progress;
    if (difference.abs() <= precision) break;
    if (difference > 0) {
      high = current;
    } else {
      low = current;
    }
  }
  return _polynomial(current, y1, y2);
}

double motionBezier(
  double x1,
  double y1,
  double x2,
  double y2,
  double progress,
) => _bezier(x1, y1, x2, y2, progress, 12, .0000001);
double cssBezier(double x1, double y1, double x2, double y2, double progress) =>
    _bezier(x1, y1, x2, y2, progress, 52, 1e-12);
