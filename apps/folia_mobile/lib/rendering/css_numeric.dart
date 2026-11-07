import 'dart:typed_data';

// Blink's computed opacity and resolved CSS Length use float32 before painting/serialization. Reuse a per-isolate scratch cell instead of allocating a typed buffer per property per frame.
final _cssFloat = Float32List(1);
double cssFloat32(double value) {
  _cssFloat[0] = value;
  return _cssFloat[0];
}
