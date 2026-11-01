import 'dart:math' as math;

import 'wall_types.dart';

// Native pointer/wheel input retains original source classification and decay: trackpads follow directly, discrete notches accumulate smooth displacement.
class WallPanInertia {
  static const minSpeed = 40.0,
      maxSpeed = 4000.0,
      power = .3,
      timeConstant = 280.0,
      restDelta = .5,
      staleReleaseMs = 80.0;
}

enum WallWheelSource { wheel, trackpad }

class WallWheelSample {
  const WallWheelSample(
    this.deltaX,
    this.deltaY,
    this.timestamp, {
    this.deltaMode = 0,
    this.shift = false,
  });
  final double deltaX, deltaY, timestamp;
  final int deltaMode;
  final bool shift;
}

class WallWheelClassifier {
  double _last = double.negativeInfinity;
  WallWheelSource? _gesture;
  WallWheelSource classify(WallWheelSample event) {
    final same = event.timestamp - _last <= 120;
    _last = event.timestamp;
    if (!same) _gesture = null;
    if (event.deltaMode != 0) return _gesture = WallWheelSource.wheel;
    final x = event.deltaX.abs(),
        y = event.deltaY.abs(),
        single = (x == 0) != (y == 0);
    return _gesture =
        !single || math.max(x, y) < 50 || _gesture == WallWheelSource.trackpad
        ? WallWheelSource.trackpad
        : WallWheelSource.wheel;
  }
}

WallPoint wallWheelDelta(WallWheelSample event, double viewportHeight) {
  final unit = event.deltaMode == 1
      ? 16.0
      : event.deltaMode == 2
      ? viewportHeight
      : 1.0;
  final horizontal = event.shift && event.deltaX == 0;
  return WallPoint(
    (horizontal ? event.deltaY : event.deltaX) * unit,
    (horizontal ? 0 : event.deltaY) * unit,
  );
}

({WallPoint step, WallPoint pending}) stepWallWheel(
  WallPoint pending,
  double dtMs,
) {
  final dt = dtMs.clamp(0, 50), factor = 1 - math.exp(-dt / 80);
  final step = WallPoint(pending.x * factor, pending.y * factor),
      after = WallPoint(pending.x - step.x, pending.y - step.y);
  return math.sqrt(after.x * after.x + after.y * after.y) < .5
      ? (step: pending, pending: const WallPoint(0, 0))
      : (step: step, pending: after);
}
