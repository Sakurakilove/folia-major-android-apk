import 'dart:math' as math;

import 'physical_spring.dart';

// Source Motion inertia generator, including boundary capture at the sampled frame and analytical decay velocity for a possible bounce.
class MotionInertia {
  MotionInertia(
    double origin, {
    double velocity = 0,
    double power = .8,
    this.timeConstant = 325,
    this.bounceDamping = 10,
    this.bounceStiffness = 500,
    this.min,
    this.max,
    this.restDelta = .5,
    this.restSpeed,
    double Function(double)? modifyTarget,
  }) : _value = origin {
    _amplitude = power * velocity;
    final ideal = origin + _amplitude;
    _target = modifyTarget?.call(ideal) ?? ideal;
    if (_target != ideal) _amplitude = _target - origin;
    _checkBoundary(0);
  }
  final double timeConstant, bounceDamping, bounceStiffness, restDelta;
  final double? min, max, restSpeed;
  late double _amplitude, _target;
  double _value;
  bool _done = false;
  double? _sampled, _boundaryTime;
  MotionPhysicalSpring? _spring;
  double _delta(double t) => -_amplitude * math.exp(-t / timeConstant);
  bool _outside(double value) =>
      (min != null && value < min!) || (max != null && value > max!);
  double _nearest(double value) => min == null
      ? max!
      : max == null
      ? min!
      : (min! - value).abs() < (max! - value).abs()
      ? min!
      : max!;
  void _checkBoundary(double t) {
    if (!_outside(_value)) return;
    _boundaryTime = t;
    _spring = MotionPhysicalSpring(
      bounceStiffness,
      bounceDamping,
      1,
      _value,
      _nearest(_value),
      -_delta(t) / timeConstant * 1000,
      restDelta: restDelta,
      restSpeed: restSpeed,
    );
  }

  void _friction(double t) {
    final delta = _delta(t);
    _done = delta.abs() <= restDelta;
    _value = _done ? _target : _target + delta;
  }

  void _sample(double milliseconds) {
    if (_sampled == milliseconds) return;
    _sampled = milliseconds;
    var updated = false;
    if (_spring == null && _boundaryTime == null) {
      updated = true;
      _friction(milliseconds);
      _checkBoundary(milliseconds);
    }
    if (_boundaryTime != null && milliseconds >= _boundaryTime!) {
      final t = (milliseconds - _boundaryTime!) / 1000;
      _value = _spring!.x(t);
      _done = _spring!.isDone(t);
    } else if (!updated) {
      _friction(milliseconds);
    }
  }

  double x(double milliseconds) {
    _sample(milliseconds);
    return _value;
  }

  bool isDone(double milliseconds) {
    _sample(milliseconds);
    return _done;
  }
}
