import 'bezier.dart';
import 'easing.dart';

// Native CSS cubic paths are distinct from Motion JS's finite-subdivision easing; non-native sampled linear() needs its own backend.
MotionEasing cssMotionEasing(dynamic definition) {
  if (definition is List &&
      definition.length == 4 &&
      definition.every((v) => v is num)) {
    final c = definition.map((v) => (v as num).toDouble()).toList();
    return (p) => cssBezier(c[0], c[1], c[2], c[3], p);
  }
  return switch (definition) {
    'linear' => (p) => p,
    'easeIn' => (p) => cssBezier(.42, 0, 1, 1, p),
    'easeOut' => (p) => cssBezier(0, 0, .58, 1, p),
    'easeInOut' || null => (p) => cssBezier(.42, 0, .58, 1, p),
    _ => throw UnsupportedError(
      'CSS linear() sampling has not been resolved for $definition',
    ),
  };
}

dynamic cssMotionKeyframeEase(dynamic ease) =>
    ease is List && (ease.isEmpty || ease.first is! num)
    ? [for (final item in ease) cssMotionEasing(item)]
    : cssMotionEasing(ease);
