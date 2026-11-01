import 'dart:math' as math;

// Physics branch of motion-dom 13.4.2 spring.mjs (MIT; assets/motion-dom-LICENSE.md), including analytical velocity and rest snapping.
// Duration/bounce-derived springs are a separate unresolved adapter; this constructor only accepts physical parameters.
class MotionPhysicalSpring {
  MotionPhysicalSpring(
    double stiffness,
    double damping,
    double mass,
    double from,
    this.target,
    double velocity, {
    double? restSpeed,
    double? restDelta,
  }) : _delta = target - from,
       _initialVelocity = -velocity / 1000,
       _ratio = damping / (2 * math.sqrt(stiffness * mass)),
       _frequency = math.sqrt(stiffness / mass) / 1000,
       _restSpeed = restSpeed == null || restSpeed == 0
           ? (target - from).abs() < 5
                 ? .01
                 : 2
           : restSpeed,
       _restDelta = restDelta == null || restDelta == 0
           ? (target - from).abs() < 5
                 ? .005
                 : .5
           : restDelta;
  final double target,
      _delta,
      _initialVelocity,
      _ratio,
      _frequency,
      _restSpeed,
      _restDelta;
  late final _decay = _ratio * _frequency;
  late final _angular = _frequency * math.sqrt((_ratio * _ratio - 1).abs());
  late final _a = (_initialVelocity + _decay * _delta) / _angular;
  double? _sampled;
  double _position = 0, _speed = 0;
  bool _done = false;

  void _sample(double seconds) {
    if (_sampled == seconds) return;
    _sampled = seconds;
    final t = seconds * 1000, envelope = math.exp(-_decay * t);
    if (_ratio < 1) {
      final sin = math.sin(_angular * t), cos = math.cos(_angular * t);
      _position = target - envelope * (_a * sin + _delta * cos);
      _speed =
          envelope *
          ((_decay * _a + _delta * _angular) * sin +
              (_decay * _delta - _a * _angular) * cos) *
          1000;
    } else if (_ratio == 1) {
      final c = _initialVelocity + _frequency * _delta;
      _position = target - envelope * (_delta + c * t);
      _speed = envelope * (_frequency * c * t - _initialVelocity) * 1000;
    } else {
      final frequencyTime = math.min(_angular * t, 300.0),
          positive = math.exp(frequencyTime),
          negative = math.exp(-frequencyTime),
          sinh = (positive - negative) / 2,
          cosh = (positive + negative) / 2;
      _position =
          target -
          envelope *
              ((_initialVelocity + _decay * _delta) * sinh +
                  _angular * _delta * cosh) /
              _angular;
      _speed =
          envelope *
          ((_decay * _a - _delta * _angular) * sinh +
              (_decay * _delta - _a * _angular) * cosh) *
          1000;
    }
    _done =
        _speed.abs() <= _restSpeed && (target - _position).abs() <= _restDelta;
  }

  double x(double seconds) {
    _sample(seconds);
    return _done ? target : _position;
  }

  double dx(double seconds) {
    _sample(seconds);
    return _speed;
  }

  bool isDone(double seconds) {
    _sample(seconds);
    return _done;
  }
}
