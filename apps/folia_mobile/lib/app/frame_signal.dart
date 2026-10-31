import '../rendering/repaint_signal.dart';

// Shared scene time repaints only listeners, never the whole widget tree.
class FrameSignal extends RepaintSignal {
  final stopwatch = Stopwatch()..start();
  double get seconds => stopwatch.elapsedMicroseconds / 1e6;
  void tick() => invalidate();
}
