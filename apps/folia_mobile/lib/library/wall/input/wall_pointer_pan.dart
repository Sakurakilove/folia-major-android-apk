import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../visualizer/motion/inertia.dart';
import '../wall_pan_motion.dart';
import '../wall_types.dart';
import '../wall_view.dart';

part 'wall_pointer_gestures.dart';
part 'wall_pointer_wheel.dart';

// Raw input owns no platform channel or permanent ticker. The host commits needed seats before exposing each camera.
class WallPointerSample {
  const WallPointerSample(
    this.id,
    this.x,
    this.y,
    this.timestamp, {
    this.touch = false,
    this.primary = true,
    this.button = 0,
    this.control = false,
    this.editable = false,
  });
  final int id, button;
  final double x, y, timestamp;
  final bool touch, primary, control, editable;
  WallPoint get point => WallPoint(x, y);
}

class WallPointerPan {
  WallPointerPan({
    required this.frames,
    required this.nowMs,
    required this.readCamera,
    required this.applyCamera,
    required this.worldBounds,
    required this.readCullBounds,
    required this.viewportHeight,
    required this.stopExternalAnimation,
    required this.overscan,
    this.onScaleCommit,
    this.onRelease,
    this.reducedMotion = false,
    this.androidTouch = true,
  });
  final Listenable frames;
  final double Function() nowMs, viewportHeight;
  final WallCamera Function() readCamera;
  final WallBounds Function(WallCamera) worldBounds;
  final WallBounds? Function() readCullBounds;
  final void Function(WallCamera, bool forceCull) applyCamera;
  final VoidCallback stopExternalAnimation;
  final ValueChanged<double>? onScaleCommit;
  final VoidCallback? onRelease;
  final double overscan;
  final bool androidTouch;
  bool reducedMotion, didDrag = false;
  bool _attached = false,
      _closed = false,
      _active = true,
      _handoff = false,
      _pinchPending = false;
  final _touches = <int, WallPoint>{};
  final _classifier = WallWheelClassifier();
  _Pan? _pan;
  ({WallCamera camera, WallTouchPair pair})? _pinch;
  WallCamera? _pending;
  WallPoint? _wheel;
  _Coast? _coast;
  double? _wheelTime, _latchUntil;
  WallPoint? _latchPoint;
  bool get pinching => _pinch != null;
  bool get panning => _pan != null;
  bool get animating => _wheel != null || _coast != null;

  void _write(WallCamera next) {
    final visible = worldBounds(next),
        cull = readCullBounds(),
        padding = overscan - 180;
    final near =
        cull == null ||
        visible.left < cull.left - padding ||
        visible.right > cull.right + padding ||
        visible.top < cull.top - padding ||
        visible.bottom > cull.bottom + padding;
    applyCamera(next, near);
  }

  void _sync() {
    final wanted =
        !_closed && _active && (_pending != null || _pinchPending || animating);
    if (wanted == _attached) return;
    _attached = wanted;
    if (wanted) {
      frames.addListener(_frame);
    } else {
      frames.removeListener(_frame);
    }
  }

  void flushCamera() {
    var next = _pending;
    if (_pinchPending && _pinch != null && _touches.length == 2) {
      final points = _touches.values.toList(growable: false);
      next = pinchWallCamera(
        _pinch!.camera,
        _pinch!.pair,
        WallTouchPair.fromPoints(points[0], points[1]),
      );
    }
    _pending = null;
    _pinchPending = false;
    if (next != null) _write(next);
    _sync();
  }

  void stopAnimation() {
    _coast = null;
    _wheel = null;
    _wheelTime = null;
    _sync();
  }

  void interrupt() {
    stopExternalAnimation();
    stopAnimation();
    flushCamera();
  }

  void cancel({bool commitScale = true}) {
    if (_closed) return;
    final wasPinching = pinching;
    _pending = null;
    _pinchPending = false;
    _pan = null;
    _pinch = null;
    _touches.clear();
    interrupt();
    if (wasPinching && commitScale) {
      final camera = readCamera();
      applyCamera(camera, true);
      onScaleCommit?.call(camera.scale);
    }
  }

  void setActive(bool value) {
    if (_closed || value == _active) return;
    if (!value) {
      cancel();
      _releaseLatch();
    }
    _active = value;
    _sync();
  }

  void _frame() {
    if (_closed || !_active) return;
    flushCamera();
    final now = nowMs(), wheel = _wheel;
    if (wheel != null) {
      if (_handoff) {
        stopAnimation();
        return;
      }
      final step = stepWallWheel(
        wheel,
        _wheelTime == null ? 1000 / 60 : now - _wheelTime!,
      );
      _wheelTime = now;
      final from = readCamera(),
          x = from.x + step.step.x,
          y = from.y + step.step.y;
      _write(WallCamera(x, y, from.scale));
      final actual = readCamera();
      _wheel = WallPoint(
        (actual.x - x).abs() > .5 ? 0 : step.pending.x,
        (actual.y - y).abs() > .5 ? 0 : step.pending.y,
      );
      if (_wheel!.x == 0 && _wheel!.y == 0) {
        _wheel = null;
        _wheelTime = null;
      }
    }
    final coast = _coast;
    if (coast != null) {
      final t = (now - coast.start).roundToDouble(),
          distance = coast.motion.x(t);
      _write(
        WallCamera(
          coast.from.x + distance * coast.dx,
          coast.from.y + distance * coast.dy,
          readCamera().scale,
        ),
      );
      if (coast.motion.isDone(t)) _coast = null;
    }
    _sync();
  }

  void dispose() {
    if (_closed) return;
    cancel(commitScale: false);
    _releaseLatch();
    _closed = true;
    _sync();
  }
}
