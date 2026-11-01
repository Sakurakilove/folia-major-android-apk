import 'dart:typed_data';
import 'dart:math' as math;

// Matches the original 0..255 power/band signals; Dart owns these arrays even after the native reader closes.
class SpectrumSnapshot {
  final bins = Uint8List(1024);
  final bands = Float64List(5);
  int sequence = 0,
      generation = 0,
      sampledAtNs = 0,
      sampleRate = 0,
      binCount = 0;
  double power = 0;
  double get bass => bands[0];
  double get lowMid => bands[1];
  double get mid => bands[2];
  double get vocal => bands[3];
  double get treble => bands[4];
  void idle(double wallClockMs) {
    final breath = idleBreath(wallClockMs);
    power = breath;
    bands.fillRange(0, bands.length, breath);
    binCount = 0;
  }
}

// Wall-clock phase is supplied by the frame owner, shared with every idle consumer.
double idleBreath(double wallClockMs) =>
    (math.sin(wallClockMs / 2000) + 1) * 20;
