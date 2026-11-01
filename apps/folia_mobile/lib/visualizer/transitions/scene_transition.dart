import 'package:flutter/animation.dart';

// softFocus.ts timings are shared by all styles; a leaving background remains opaque until the incoming surface covers it.
class SceneTransition {
  const SceneTransition({required this.leave, required this.enter});
  final SceneTransitionTrack leave, enter;
  static const softFocus = SceneTransition(
    leave: SceneTransitionTrack(
      opacity: 0,
      blur: 8,
      scale: 1.02,
      durationMs: 360,
      curve: Cubic(.4, 0, 1, 1),
    ),
    enter: SceneTransitionTrack(
      opacity: 0,
      blur: 8,
      scale: 1.02,
      delayMs: 80,
      durationMs: 520,
      curve: Cubic(.16, 1, .3, 1),
    ),
  );
  SceneTransition underNext() => SceneTransition(
    enter: enter,
    leave: SceneTransitionTrack(
      opacity: 1,
      blur: 0,
      scale: 1,
      durationMs: enter.delayMs + enter.durationMs,
      curve: Curves.linear,
    ),
  );
}

class SceneTransitionTrack {
  const SceneTransitionTrack({
    required this.opacity,
    required this.blur,
    required this.scale,
    required this.durationMs,
    required this.curve,
    this.delayMs = 0,
  });
  final double opacity, blur, scale;
  final int durationMs, delayMs;
  final Curve curve;
  double progress(double milliseconds) =>
      curve.transform(((milliseconds - delayMs) / durationMs).clamp(0.0, 1.0));
}
