import 'dart:math' as math;

import 'physical_spring.dart';
import 'scalar_value.dart';

// motion-dom FollowAnimation/attachFollow spring branch: coalesce targets until a tick and steer with analytical, not frame-estimated velocity.
class MotionFollowSpring {
  MotionFollowSpring(
    double initial, {
    this.stiffness = 100,
    this.damping = 10,
    this.mass = 1,
    this.restDelta = .001,
    this.restSpeed = .01,
  }) : _observed = MotionScalarValue(initial);
  final double stiffness, damping, mass, restDelta, restSpeed;
  final MotionScalarValue _observed;
  MotionPhysicalSpring? _spring;
  double _start = 0, _pendingTarget = 0;
  double? _pendingVelocity;
  bool _running = false, _pending = false;
  double get value => _observed.value;
  bool get isAnimating => _running;
  MotionPhysicalSpring _between(double from, double to, double velocity) =>
      MotionPhysicalSpring(
        stiffness,
        damping,
        mass,
        from,
        to,
        velocity,
        restDelta: restDelta,
        restSpeed: restSpeed,
      );
  void setTarget(double target, double now, {double? velocity}) {
    if (_running) {
      _pendingTarget = target;
      _pendingVelocity = velocity;
      _pending = true;
      return;
    }
    if (value == target) return;
    _spring = _between(value, target, velocity ?? _observed.velocity(now));
    _start = now;
    _running = true;
  }

  void advance(double now) {
    if (!_running) return;
    final elapsed = math.max(0.0, (now - _start + .5).floorToDouble()),
        spring = _spring!;
    final next = spring.x(elapsed / 1000), done = spring.isDone(elapsed / 1000);
    if (_pending) {
      final velocity = _pendingVelocity ?? spring.dx(elapsed / 1000);
      _pending = false;
      _spring = _between(next, _pendingTarget, velocity);
      _start = now;
    } else if (done) {
      _running = false;
    }
    _observed.recordObserved(next, now);
  }
}
