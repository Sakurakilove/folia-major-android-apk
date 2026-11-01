part of 'wall_pointer_pan.dart';

// Source wheel ownership and stationary-pointer latch remain separate from raw touch gesture state.
extension WallPointerWheel on WallPointerPan {
  bool wheel(
    WallWheelSample event, {
    bool ctrl = false,
    bool meta = false,
    WallPoint? pointer,
  }) {
    if (_closed || !_active || ctrl || meta) return false;
    if (pointer != null) {
      if (_latchUntil == null || nowMs() >= _latchUntil!) _latchPoint = pointer;
      _latchUntil = nowMs() + 160;
    }
    if (_pan != null || _handoff) return true;
    final source = _classifier.classify(event),
        delta = wallWheelDelta(event, viewportHeight());
    if (source == WallWheelSource.trackpad || reducedMotion) {
      final carry = _wheel ?? const WallPoint(0, 0), from = readCamera();
      stopExternalAnimation();
      stopAnimation();
      _write(
        WallCamera(
          from.x + carry.x - delta.x,
          from.y + carry.y - delta.y,
          from.scale,
        ),
      );
    } else {
      if (_wheel == null) {
        stopExternalAnimation();
        stopAnimation();
        _wheel = const WallPoint(0, 0);
      }
      _wheel = WallPoint(_wheel!.x - delta.x, _wheel!.y - delta.y);
      _sync();
    }
    return true;
  }

  void hoverPointer(WallPoint point) {
    if (_latchPoint != null && _distance(point, _latchPoint!) > 4) {
      _releaseLatch();
    }
  }

  bool get wheelLatched => _latchUntil != null && nowMs() < _latchUntil!;
  void _releaseLatch() {
    _latchUntil = null;
    _latchPoint = null;
  }

  void setHandoff(bool value) {
    _handoff = value;
    if (value) stopAnimation();
  }
}
