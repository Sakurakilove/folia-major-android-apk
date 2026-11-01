import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../visualizer/motion/bezier.dart';
import '../wall/finite_wall.dart';
import '../wall/input/wall_pointer_pan.dart';
import '../wall/wall_types.dart';
import '../wall/wall_view.dart';
import 'bravais_frame.dart';

// The same world-centre camera drives raw touch, finite rubber bands, wheel inertia and finite source tweens.
class BravaisCamera {
  BravaisCamera({
    required this.frames,
    required this.nowMs,
    required this.view,
    required this.center,
    this.anchorX,
    this.openWidth = 0,
    this.contentWidth = 0,
    this.hidden = false,
    this.poster = false,
    this.tiltDeg = 0,
    this.reducedMotion = false,
    this.overscan = 300,
    ValueChanged<double>? onScaleCommit,
  }) {
    frame = ValueNotifier(_computeFrame());
    pointer = WallPointerPan(
      frames: frames,
      nowMs: nowMs,
      readCamera: () => cameraFromViewCenter(center, view),
      applyCamera: _applyCamera,
      worldBounds: (camera) => viewWorldBounds(
        viewCenterFromCamera(camera, view),
        view.withScale(camera.scale),
        seamWidth: openWidth,
      ),
      readCullBounds: () => cull.value,
      viewportHeight: () => view.height,
      stopExternalAnimation: _stopTween,
      overscan: overscan,
      onScaleCommit: onScaleCommit,
      reducedMotion: reducedMotion,
    );
    checkCull(force: true);
  }
  final Listenable frames;
  final double Function() nowMs;
  final double overscan;
  WallView view;
  WallPoint center;
  double? anchorX;
  double openWidth, contentWidth, tiltDeg;
  bool hidden, poster, reducedMotion;
  late final ValueNotifier<BravaisFrame> frame;
  final cull = ValueNotifier<WallBounds?>(null);
  late final WallPointerPan pointer;
  WallCameraRange? range;
  bool _dragging = false,
      _tweenAttached = false,
      _closed = false,
      _active = true;
  ({WallPoint from, WallPoint to, double start, double duration})? _tween;
  BravaisFrame _computeFrame() => computeBravaisFrame(
    center: center,
    view: view,
    anchorX: anchorX,
    openWidth: openWidth,
    contentWidth: contentWidth,
    hidden: hidden,
    poster: poster,
    tiltDeg: tiltDeg,
  );
  WallBounds get visible => bravaisVisibleWorldBounds(
    center: center,
    view: view,
    anchorX: anchorX,
    openWidth: openWidth,
    contentWidth: contentWidth,
    hidden: hidden,
    poster: poster,
    tiltDeg: tiltDeg,
  );
  void _publish(WallBounds value) {
    final old = cull.value;
    if (old != null &&
        old.left == value.left &&
        old.right == value.right &&
        old.top == value.top &&
        old.bottom == value.bottom) {
      return;
    }
    cull.value = value;
  }

  void checkCull({bool force = false}) {
    final bounds = visible;
    if (force || bravaisNeedsRecull(bounds, cull.value, overscan: overscan)) {
      _publish(bounds);
    }
  }

  void renderFrame({bool forceCull = false}) {
    if (_closed) return;
    checkCull(force: forceCull);
    frame.value = _computeFrame();
  }

  void moveTo(
    WallPoint value, {
    bool forceCull = false,
    bool synchronous = false,
  }) {
    if (_closed) return;
    center = value;
    final bounds = visible;
    if (forceCull ||
        bravaisNeedsRecull(bounds, cull.value, overscan: overscan) ||
        (synchronous &&
            bravaisNeedsRecull(
              bounds,
              cull.value,
              prepare: true,
              overscan: overscan,
            ))) {
      // Flutter builds the published seat set before painting the newly invalidated native camera layer.
      _publish(bounds);
    }
    frame.value = _computeFrame();
  }

  void _applyCamera(WallCamera camera, bool updateBounds) {
    if (camera.scale != view.scale) view = view.withScale(camera.scale);
    var next = viewCenterFromCamera(camera, view);
    final limit = range;
    if (limit != null) {
      next = _dragging
          ? WallPoint(
              bravaisRubberBand(next.x, limit.minX, limit.maxX),
              bravaisRubberBand(next.y, limit.minY, limit.maxY),
            )
          : clampToCameraRange(next, limit);
    }
    moveTo(next, forceCull: updateBounds, synchronous: true);
  }

  void _stopTween() {
    _tween = null;
    if (_tweenAttached) {
      _tweenAttached = false;
      frames.removeListener(_tickTween);
    }
  }

  void stopCamera() {
    _stopTween();
    pointer.stopAnimation();
  }

  void tweenTo(WallPoint target, {double duration = 420}) {
    if (_closed) return;
    stopCamera();
    final from = center;
    if ((target.x - from.x).abs() < .5 && (target.y - from.y).abs() < .5) {
      return;
    }
    final destination = viewWorldBounds(target, view, seamWidth: openWidth),
        current = cull.value;
    if (current == null) {
      _publish(destination);
    } else {
      final merged = WallBounds(
        math.min(current.left, destination.left),
        math.max(current.right, destination.right),
        math.min(current.top, destination.top),
        math.max(current.bottom, destination.bottom),
      );
      double area(WallBounds b) => (b.right - b.left) * (b.bottom - b.top);
      if (area(merged) <= area(destination) * 3) _publish(merged);
    }
    if (reducedMotion || duration <= 0) {
      moveTo(target, forceCull: true);
      return;
    }
    _tween = (from: from, to: target, start: nowMs(), duration: duration);
    if (_active) {
      _tweenAttached = true;
      frames.addListener(_tickTween);
    }
  }

  void _tickTween() {
    final tween = _tween;
    if (_closed || tween == null) return;
    final time = (nowMs() - tween.start).roundToDouble(),
        p = (time / tween.duration).clamp(0.0, 1.0),
        value = motionBezier(.22, 1, .36, 1, p);
    moveTo(
      WallPoint(
        tween.from.x + (tween.to.x - tween.from.x) * value,
        tween.from.y + (tween.to.y - tween.from.y) * value,
      ),
    );
    if (p >= 1) {
      _stopTween();
      moveTo(tween.to, forceCull: true);
    }
  }

  void settle() {
    final limit = range;
    if (limit == null) return;
    final target = clampToCameraRange(center, limit);
    if ((target.x - center.x).abs() > .5 || (target.y - center.y).abs() > .5) {
      tweenTo(target);
    }
  }

  void setRange(WallCameraRange? value, {bool settleNow = false}) {
    range = value;
    if (value != null && settleNow) settle();
  }

  void pointerDown(WallPointerSample event) {
    _dragging = true;
    pointer.pointerDown(event);
  }

  void pointerMove(WallPointerSample event) => pointer.pointerMove(event);
  void pointerUp(WallPointerSample event) {
    pointer.pointerUp(event);
    _dragging = false;
    if (!pointer.animating && _tween == null) settle();
  }

  void pointerCancel(WallPointerSample event) {
    pointer.pointerCancel(event);
    _dragging = false;
    settle();
  }

  void setActive(bool active) {
    if (_closed || active == _active) return;
    _active = active;
    pointer.setActive(active);
    if (!active) {
      _dragging = false;
      _stopTween();
    }
  }

  void dispose() {
    if (_closed) return;
    stopCamera();
    pointer.dispose();
    _closed = true;
    frame.dispose();
    cull.dispose();
  }
}
