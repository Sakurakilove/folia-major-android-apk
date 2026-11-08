import 'dart:typed_data';

// Blink's computed opacity and resolved CSS Length use float32 before painting/serialization. Reuse a per-isolate scratch cell instead of allocating a typed buffer per property per frame.
final _cssFloat = Float32List(1);
double cssFloat32(double value) {
  _cssFloat[0] = value;
  return _cssFloat[0];
}

// Blink LayoutUnit stores signed 26.6 values. Its float/double constructors
// saturate and truncate toward zero (negative centered overflow is not floor).
double cssLayoutUnit(double value) {
  if (value.isNaN) return 0;
  final raw = (value * 64).clamp(-2147483648.0, 2147483647.0);
  return raw.truncateToDouble() / 64;
}

double cssLayoutLength(double value) => cssLayoutUnit(cssFloat32(value));
double cssLayoutPercent(double extent, double percent) =>
    cssLayoutLength(cssFloat32(percent) * extent / 100);
