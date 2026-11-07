import 'package:flutter/foundation.dart';

import '../../../visualizer/motion/scalar_value.dart';
import '../../wall/seam_plan.dart';
import '../../wall/wall_types.dart';
import '../bravais_camera.dart';
import '../bravais_frame.dart';
import '../shape/bravais_wall_shape.dart';
import 'bravais_seam_level.dart';
import 'bravais_seam_target.dart';

part 'bravais_seam_opening_plan.dart';

// Original 360ms opening and delayed 950/500ms poster tilt share the scene clock. They write native camera/frame data, never widget state or a channel.
class BravaisSeamOpening {
  BravaisSeamOpening({
    required this.frames,
    required this.nowMs,
    required this.camera,
    required this.getShape,
    required String? layerKey,
    required BravaisSeamTarget target,
    this.reducedMotion = false,
    this._active = true,
  }) : _layerKey = layerKey,
       _target = target,
       _width = MotionScalarValue(camera.openWidth),
       _tilt = MotionScalarValue(camera.tiltDeg) {
    camera.poster =
        layerKey != null && target.variant == BravaisSeamVariant.poster;
    camera.hidden =
        layerKey != null && target.variant == BravaisSeamVariant.none;
    _animateWidth(targetWidth);
    _animateTilt(camera.poster);
  }
  final Listenable frames;
  final double Function() nowMs;
  final BravaisCamera camera;
  final BravaisWallShape Function() getShape;
  final MotionScalarValue _width, _tilt;
  String? _layerKey;
  BravaisSeamTarget _target;
  bool reducedMotion, _active, _attached = false, _closed = false;
  double _widthStart = 0, _tiltStart = 0;
  double get targetWidth => _layerKey == null ? 0 : _target.width;
  void update({
    required String? layerKey,
    required BravaisSeamTarget target,
    required bool reducedMotion,
  }) {
    if (_closed) return;
    final previousKey = _layerKey,
        previousWidth = targetWidth,
        previousHidden = camera.hidden,
        previousPoster = camera.poster,
        reductionChanged = this.reducedMotion != reducedMotion;
    this.reducedMotion = reducedMotion;
    _layerKey = layerKey;
    _target = target;
    camera.poster =
        layerKey != null && target.variant == BravaisSeamVariant.poster;
    camera.hidden =
        layerKey != null && target.variant == BravaisSeamVariant.none;
    if (previousPoster != camera.poster || reductionChanged) {
      _animateTilt(camera.poster);
    }
    if (previousWidth != targetWidth ||
        previousHidden != camera.hidden ||
        reductionChanged) {
      _animateWidth(targetWidth);
    } else if (previousPoster != camera.poster) {
      camera.renderFrame();
    }
    if (previousKey == layerKey &&
        previousWidth != targetWidth &&
        layerKey != null &&
        targetWidth > 0) {
      final plan = planOpening(
        camera.center,
        targetWidth,
        isAnchorOnScreen(),
        poster: camera.poster,
      );
      setAnchor(plan.anchorX);
      camera.tweenTo(plan.center);
    }
  }

  void _animateWidth(double to, {double? from}) {
    final start = from ?? camera.openWidth, now = nowMs();
    _widthStart = now;
    _width.jump(start, now);
    if (reducedMotion || (to - start).abs() < .5) {
      final changed = (to - camera.openWidth).abs() >= .5;
      _width.jump(to, now);
      camera.openWidth = to;
      camera.renderFrame(forceCull: changed);
    } else {
      _width.animate('openWidth', to, {
        'duration': .36,
        'ease': [.65, 0, .35, 1],
      }, now);
      camera.openWidth = start;
      camera.renderFrame();
    }
    _sync();
  }

  void _animateTilt(bool poster) {
    final to = poster && !reducedMotion ? -10.0 : 0.0,
        from = camera.tiltDeg,
        now = nowMs();
    _tiltStart = now;
    _tilt.jump(from, now);
    if ((to - from).abs() < .01) {
      _sync();
      return;
    }
    if (reducedMotion) {
      _tilt.jump(to, now);
      camera.tiltDeg = to;
      camera.renderFrame(forceCull: true);
    } else {
      final turningIn = to.abs() > from.abs();
      _tilt.animate('tiltDeg', to, {
        'duration': turningIn ? .95 : .5,
        'delay': turningIn ? .12 : 0,
        'ease': [.45, 0, .2, 1],
      }, now);
    }
    _sync();
  }

  void _frame() {
    if (_closed || !_active) return;
    final now = nowMs(),
        widthRunning = _width.isAnimating,
        tiltRunning = _tilt.isAnimating;
    _width.advance(_widthStart + (now - _widthStart).roundToDouble());
    _tilt.advance(_tiltStart + (now - _tiltStart).roundToDouble());
    camera.openWidth = _width.value;
    camera.tiltDeg = _tilt.value;
    camera.renderFrame(
      forceCull:
          (widthRunning && !_width.isAnimating) ||
          (tiltRunning && !_tilt.isAnimating),
    );
    _sync();
  }

  void _sync() {
    final wanted =
        !_closed && _active && (_width.isAnimating || _tilt.isAnimating);
    if (wanted == _attached) return;
    _attached = wanted;
    if (wanted) {
      frames.addListener(_frame);
    } else {
      frames.removeListener(_frame);
    }
  }

  void setActive(bool value) {
    if (_closed || value == _active) return;
    _active = value;
    if (value) _frame();
    _sync();
  }

  void dispose() {
    _closed = true;
    _sync();
  }
}
