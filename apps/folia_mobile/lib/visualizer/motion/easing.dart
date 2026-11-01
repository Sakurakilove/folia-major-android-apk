import 'dart:math' as math;

import 'bezier.dart';

// motion-utils' complete named easing table; numeric paths use the original JS curves rather than Flutter defaults.
typedef MotionEasing = double Function(double progress);
MotionEasing _reverse(MotionEasing ease) =>
    (p) => 1 - ease(1 - p);
MotionEasing _mirror(MotionEasing ease) =>
    (p) => p <= .5 ? ease(2 * p) / 2 : (2 - ease(2 * (1 - p))) / 2;
double _circIn(double p) => 1 - math.sin(math.acos(p));
double _backOut(double p) => motionBezier(.33, 1.53, .69, .99, p);
final _backIn = _reverse(_backOut);
MotionEasing motionEasing(dynamic definition) {
  if (definition is MotionEasing) return definition;
  if (definition is List) {
    if (definition.length != 4 || definition.any((n) => n is! num)) {
      throw ArgumentError('Cubic bezier needs four numbers');
    }
    final points = definition
        .map((n) => (n as num).toDouble())
        .toList(growable: false);
    return (p) => motionBezier(points[0], points[1], points[2], points[3], p);
  }
  return switch (definition) {
    'linear' => (p) => p,
    'easeIn' => (p) => motionBezier(.42, 0, 1, 1, p),
    'easeOut' => (p) => motionBezier(0, 0, .58, 1, p),
    'easeInOut' || null => (p) => motionBezier(.42, 0, .58, 1, p),
    'circIn' => _circIn,
    'circOut' => _reverse(_circIn),
    'circInOut' => _mirror(_circIn),
    'backIn' => _backIn,
    'backOut' => _backOut,
    'backInOut' => _mirror(_backIn),
    'anticipate' =>
      (p) => p >= 1
          ? 1
          : p * 2 < 1
          ? .5 * _backIn(p * 2)
          : .5 * (2 - math.pow(2, -10 * (p * 2 - 1))),
    _ => throw ArgumentError.value(definition, 'easing'),
  };
}
