import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';

import 'monet_rail_layout.dart';
import '../../visualizer/motion/physical_spring.dart';
import '../../visualizer/motion/motion_curves.dart';

// The original entry/retarget/exit contract: two springs and independent opacity/blur easing, not one global fade.
class MonetRailMotion {
  MonetRailMotion(
    this.entry,
    double now, {
    bool manual = false,
    bool suppressInitial = false,
  }) : start = now,
       subtitleStart = now - (suppressInitial ? .32 : 0),
       _y = _spring(
         _scroll,
         entry.y +
             (manual || suppressInitial
                 ? 0
                 : entry.entry.offset >= 0
                 ? 34
                 : -34),
         entry.y,
         0,
       ),
       _scale = _spring(
         _scaleDescription,
         entry.tone.scale * (manual || suppressInitial ? 1 : .98),
         entry.tone.scale,
         0,
       ),
       _fromOpacity = manual || suppressInitial ? entry.tone.opacity : 0,
       _fromBlur = manual || suppressInitial ? entry.tone.blur : 5,
       _chorusStart = now - (suppressInitial ? .45 : 0),
       _chorusTarget = entry.entry.status == 'active' ? 1 : 0,
       _chorusScaleTarget = entry.entry.status == 'active' ? 1.02 : .96;
  static MotionPhysicalSpring _spring(
    SpringDescription spec,
    double from,
    double target,
    double velocity,
  ) => MotionPhysicalSpring(
    spec.stiffness,
    spec.damping,
    spec.mass,
    from,
    target,
    velocity,
  );
  static const _scroll = SpringDescription(
    mass: .82,
    stiffness: 142,
    damping: 28,
  );
  static const _scaleDescription = SpringDescription(
    mass: .78,
    stiffness: 150,
    damping: 30,
  );
  static const _ease = CssBezierCurve(.32, .72, 0, 1),
      _motionEase = MotionBezierCurve(.32, .72, 0, 1);
  PositionedMonetLineEntry entry;
  MotionPhysicalSpring _y, _scale;
  double start, subtitleStart, _fromOpacity, _fromBlur;
  double? _exitStart;
  double _exitY = 0, _exitScale = 1, _exitOpacity = 0, _exitBlur = 0;
  double _chorusStart, _chorusTarget, _chorusScaleTarget;
  double _chorusFrom = 0, _chorusScaleFrom = 1;
  static const _chorusEase = CssBezierCurve(0, 0, .58, 1),
      _chorusMotionEase = MotionBezierCurve(0, 0, .58, 1);
  double _chorusTime(double now, {bool motion = false}) =>
      (motion ? _chorusMotionEase : _chorusEase).transform(
        ((now - _chorusStart) / .45).clamp(0.0, 1.0),
      );
  double chorusOpacity(double now) =>
      ui.lerpDouble(_chorusFrom, _chorusTarget, _chorusTime(now))!;
  double chorusScale(double now) => ui.lerpDouble(
    _chorusScaleFrom,
    _chorusScaleTarget,
    _chorusTime(now, motion: true),
  )!;

  double _easeTime(double now, double duration) =>
      _ease.transform(((now - start) / duration).clamp(0.0, 1.0));
  double _exitTime(double now, {bool css = false}) =>
      (css ? _ease : _motionEase).transform(
        ((now - _exitStart!) / .2).clamp(0.0, 1.0),
      );
  double y(double now) => _exitStart == null
      ? _y.x(math.max(0, now - start))
      : ui.lerpDouble(
          _exitY,
          entry.y +
              (entry.entry.status == 'passed' || entry.entry.offset < 0
                  ? -38
                  : 38),
          _exitTime(now),
        )!;
  double scale(double now) => _exitStart == null
      ? _scale.x(math.max(0, now - start))
      : ui.lerpDouble(_exitScale, entry.tone.scale * .98, _exitTime(now))!;
  double opacity(double now) => _exitStart == null
      ? ui.lerpDouble(_fromOpacity, entry.tone.opacity, _easeTime(now, .28))!
      : ui.lerpDouble(_exitOpacity, 0, _exitTime(now, css: true))!;
  double blur(double now) => _exitStart == null
      ? ui.lerpDouble(_fromBlur, entry.tone.blur, _easeTime(now, .32))!
      : ui.lerpDouble(_exitBlur, 6, _exitTime(now, css: true))!;
  bool get exiting => _exitStart != null;
  bool exited(double now) => _exitStart != null && now - _exitStart! >= .2;
  bool animating(double now) => _exitStart != null
      ? !exited(now)
      : now - start < .32 ||
            entry.entry.line.isChorus && now - _chorusStart < .45 ||
            !_y.isDone(math.max(0, now - start)) ||
            !_scale.isDone(math.max(0, now - start));

  void target(PositionedMonetLineEntry next, double now) {
    final previous = entry;
    final chorus = next.entry.status == 'active' ? 1.0 : 0.0;
    if (chorus != _chorusTarget) {
      _chorusFrom = chorusOpacity(now);
      _chorusScaleFrom = chorusScale(now);
      _chorusStart = now;
      _chorusTarget = chorus;
      _chorusScaleTarget = chorus == 1 ? 1.02 : .96;
    }
    if (next.layout.subtitleTracks.isNotEmpty &&
        previous.layout.subtitleTracks.isEmpty) {
      subtitleStart = now;
    }
    if (!exiting &&
        next.y == entry.y &&
        next.tone.scale == entry.tone.scale &&
        next.tone.opacity == entry.tone.opacity &&
        next.tone.blur == entry.tone.blur) {
      entry = next;
      return;
    }
    final elapsed = math.max(0.0, now - start),
        currentY = y(now),
        currentScale = scale(now);
    final opacityNow = opacity(now), blurNow = blur(now);
    _y = _spring(_scroll, currentY, next.y, exiting ? 0 : _y.dx(elapsed));
    _scale = _spring(
      _scaleDescription,
      currentScale,
      next.tone.scale,
      exiting ? 0 : _scale.dx(elapsed),
    );
    _fromOpacity = opacityNow;
    _fromBlur = blurNow;
    start = now;
    entry = next;
    _exitStart = null;
  }

  void exit(double now, {bool manual = false}) {
    if (exiting) return;
    _exitY = y(now);
    _exitScale = scale(now);
    _exitOpacity = opacity(now);
    _exitBlur = blur(now);
    _exitStart = manual ? now - .2 : now;
  }

  ({double opacity, double y}) subtitleMotion(int index, double now) {
    final progress = _ease.transform(
      ((now - subtitleStart - index * monetSubtitleTrackStaggerSeconds) / .28)
          .clamp(0.0, 1.0),
    );
    final yProgress = _motionEase.transform(
      ((now - subtitleStart - index * monetSubtitleTrackStaggerSeconds) / .28)
          .clamp(0.0, 1.0),
    );
    return (opacity: progress, y: 8 * (1 - yProgress));
  }
}
