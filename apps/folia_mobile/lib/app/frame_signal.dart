import '../rendering/repaint_signal.dart';

// Shared scene time repaints only listeners, never the whole widget tree.
class FrameSignal extends RepaintSignal {
  final stopwatch = Stopwatch()..start();
  final _samplers = <void Function()>{};
  double get seconds => stopwatch.elapsedMicroseconds / 1e6;
  void addSampler(void Function() sample) => _samplers.add(sample);
  void removeSampler(void Function() sample) => _samplers.remove(sample);
  void tick() {
    for (final sample in _samplers) {
      sample();
    }
    invalidate();
  }

  @override
  void dispose() {
    _samplers.clear();
    super.dispose();
  }
}
