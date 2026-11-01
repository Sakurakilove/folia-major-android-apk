part of 'wall_pointer_pan.dart';

// Pointer ownership, drag threshold, release velocity and two-touch anchoring follow the source hook.
class _Pan {
  _Pan(this.id, this.start, this.camera, this.last, this.time);
  final int id;
  final WallPoint start;
  final WallCamera camera;
  WallPoint last;
  double time, vx = 0, vy = 0;
  bool dragged = false;
}

class _Coast {
  _Coast(this.from, this.dx, this.dy, this.start, double speed)
    : motion = MotionInertia(
        0,
        velocity: speed,
        power: WallPanInertia.power,
        timeConstant: WallPanInertia.timeConstant,
        restDelta: WallPanInertia.restDelta,
      );
  final WallCamera from;
  final double dx, dy, start;
  final MotionInertia motion;
}

extension WallPointerGestures on WallPointerPan {
  void pointerDown(WallPointerSample event) {
    if (_closed || !_active || event.button != 0 || (event.touch && pinching)) {
      return;
    }
    if (event.touch && !event.control) {
      _touches[event.id] = event.point;
      if (_touches.length == 2) {
        interrupt();
        _pan = null;
        didDrag = true;
        final points = _touches.values.toList(growable: false);
        _pinch = (
          camera: readCamera(),
          pair: WallTouchPair.fromPoints(points[0], points[1]),
        );
        return;
      }
    }
    if (!event.primary || _pan != null || pinching) return;
    interrupt();
    didDrag = false;
    if (event.control || event.editable) return;
    _pan = _Pan(
      event.id,
      event.point,
      readCamera(),
      event.point,
      event.timestamp,
    );
  }

  void pointerMove(WallPointerSample event) {
    if (_closed || !_active) return;
    if (_latchPoint != null && _distance(event.point, _latchPoint!) > 4) {
      _releaseLatch();
    }
    if (_touches.containsKey(event.id)) _touches[event.id] = event.point;
    if (pinching && _touches.length >= 2) {
      _pinchPending = true;
      _sync();
      return;
    }
    final pan = _pan;
    if (pan == null || pan.id != event.id) return;
    final dx = event.x - pan.start.x, dy = event.y - pan.start.y;
    if (!pan.dragged && _hypot(dx, dy) > 7) {
      pan.dragged = true;
      didDrag = true;
    }
    final elapsed = event.timestamp - pan.time;
    if (elapsed > 0) {
      pan.vx = (event.x - pan.last.x) / elapsed * 1000;
      pan.vy = (event.y - pan.last.y) / elapsed * 1000;
    }
    pan.last = event.point;
    pan.time = event.timestamp;
    if (!pan.dragged) return;
    final next = WallCamera(
      pan.camera.x + dx,
      pan.camera.y + dy,
      readCamera().scale,
    );
    // Android touch events are already aligned to input; an extra queued frame adds visible drag latency.
    if (event.touch && androidTouch) {
      _write(next);
    } else {
      _pending = next;
      _sync();
    }
  }

  void pointerUp(WallPointerSample event) {
    if (_closed || (!_touches.containsKey(event.id) && _pan?.id != event.id)) {
      return;
    }
    flushCamera();
    _touches.remove(event.id);
    if (pinching) {
      if (_touches.length < 2) _finishPinch();
      onRelease?.call();
      return;
    }
    final pan = _pan;
    if (pan == null || pan.id != event.id) return;
    _pan = null;
    final speed = _hypot(pan.vx, pan.vy);
    if (pan.dragged &&
        !reducedMotion &&
        event.timestamp - pan.time <= WallPanInertia.staleReleaseMs &&
        speed >= WallPanInertia.minSpeed) {
      _coast = _Coast(
        readCamera(),
        pan.vx / speed,
        pan.vy / speed,
        nowMs(),
        math.min(speed, WallPanInertia.maxSpeed),
      );
      _sync();
    }
    onRelease?.call();
  }

  void pointerCancel(WallPointerSample event) {
    if (_closed || (!_touches.containsKey(event.id) && _pan?.id != event.id)) {
      return;
    }
    flushCamera();
    _touches.remove(event.id);
    if (pinching) _finishPinch();
    if (_pan?.id == event.id) {
      _pan = null;
      interrupt();
    }
    onRelease?.call();
  }

  void _finishPinch() {
    _pinch = null;
    _touches.clear();
    final camera = readCamera();
    applyCamera(camera, true);
    onScaleCommit?.call(camera.scale);
    _sync();
  }

  bool consumeClick({bool keyboard = false}) {
    if (!didDrag || keyboard) return false;
    didDrag = false;
    return true;
  }
}

double _distance(WallPoint a, WallPoint b) => _hypot(a.x - b.x, a.y - b.y);
double _hypot(double x, double y) {
  final max = math.max(x.abs(), y.abs());
  if (max == 0 || max.isInfinite) return max;
  return max * math.sqrt((x / max) * (x / max) + (y / max) * (y / max));
}
