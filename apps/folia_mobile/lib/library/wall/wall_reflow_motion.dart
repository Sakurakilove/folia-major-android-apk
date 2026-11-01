import 'dart:math' as math;

import '../../visualizer/motion/physical_spring.dart';
import '../../rendering/js_number.dart';

// Source Bravais CSS-linear samples are intentionally distinct from Lattice's direct per-property physical springs.
class WallReflowCurve {
  WallReflowCurve(double distance) {
    final span = math.max(distance.abs(), 1.0),
        generator = MotionPhysicalSpring(300, 34, 1, 0, span, 0);
    var t = 0;
    while (!generator.isDone(t / 1000) && t < 20000) {
      t++;
    }
    if (t >= 20000) {
      throw StateError(
        'Original reflow spring exceeded the source duration bound',
      );
    }
    durationMs = t.toDouble();
    final count = math.max((durationMs / 4 + .5).floor(), 2) + 1;
    points = List.unmodifiable([
      for (var i = 0; i < count; i++)
        i == count - 1
            ? 1.0
            : (generator.x((durationMs * i / (count - 1)) / 1000) / span * 1e5 +
                          .5)
                      .floor() /
                  1e5,
    ]);
  }
  late final double durationMs;
  late final List<double> points;
  String get css => 'linear(${points.map(jsNumberString).join(', ')})';
  double ease(double progress) {
    if (progress <= 0) return points[0];
    if (progress >= 1) return 1;
    final position = progress * (points.length - 1), i = position.floor();
    return points[i] + (points[i + 1] - points[i]) * (position - i);
  }
}
