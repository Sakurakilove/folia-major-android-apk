import 'dart:math' as math;

import 'physical_spring.dart';

// Motion 13.4.2 duration/bounce/visualDuration resolution; physical parameters take precedence over duration options.
class MotionSpringOptions {
  const MotionSpringOptions(
    this.stiffness,
    this.damping,
    this.mass,
    this.velocity,
    this.resolvedDurationMs, {
    this.restSpeed,
    this.restDelta,
  });
  final double stiffness, damping, mass, velocity;
  final double? resolvedDurationMs, restSpeed, restDelta;
  MotionPhysicalSpring between(double from, double target) =>
      MotionPhysicalSpring(
        stiffness,
        damping,
        mass,
        from,
        target,
        velocity,
        restSpeed: restSpeed,
        restDelta: restDelta,
        resolvedDurationMs: resolvedDurationMs,
      );
  Map<String, dynamic> toJson() => {
    'stiffness': stiffness,
    'damping': damping,
    'mass': mass,
    'velocity': velocity,
    'resolvedDurationMs': resolvedDurationMs,
  };
}

double? _number(Map<String, dynamic> options, String key) =>
    (options[key] as num?)?.toDouble();
bool _truthy(double? value) => value != null && value != 0 && !value.isNaN;

MotionSpringOptions resolveMotionSpring(Map<String, dynamic> options) {
  var stiffness = _number(options, 'stiffness') ?? 100.0,
      damping = _number(options, 'damping') ?? 10.0,
      mass = _number(options, 'mass') ?? 1.0,
      velocity = _number(options, 'velocity') ?? 0.0;
  double? duration;
  if (!['stiffness', 'damping', 'mass'].any(options.containsKey) &&
      ['duration', 'bounce'].any(options.containsKey)) {
    velocity = 0;
    final visual = _number(options, 'visualDuration');
    if (_truthy(visual)) {
      final root = (2 * math.pi) / (visual! * 1.2),
          bounce = _number(options, 'bounce');
      stiffness = root * root;
      damping =
          2 *
          (1 - (_truthy(bounce) ? bounce! : 0)).clamp(.05, 1) *
          math.sqrt(stiffness);
    } else {
      // Generator options use milliseconds; UI transition seconds are converted by the motion adapter before this boundary.
      final resolved = _findSpring(
        _number(options, 'duration') ?? 800,
        _number(options, 'bounce') ?? .3,
      );
      stiffness = resolved.stiffness;
      damping = resolved.damping;
      duration = resolved.duration;
    }
    mass = 1;
  }
  return MotionSpringOptions(
    stiffness,
    damping,
    mass,
    velocity,
    duration,
    restSpeed: _number(options, 'restSpeed'),
    restDelta: _number(options, 'restDelta'),
  );
}

({double stiffness, double damping, double duration}) _findSpring(
  double duration,
  double bounce,
) {
  final ratio = (1 - bounce).clamp(.05, 1.0),
      seconds = (duration / 1000).clamp(.01, 10.0);
  double angular(double frequency) => frequency * math.sqrt(1 - ratio * ratio);
  double envelope(double frequency) {
    final decay = frequency * ratio;
    if (ratio < 1) {
      return .001 - (decay / angular(frequency)) * math.exp(-decay * seconds);
    }
    return -.001 + math.exp(-frequency * seconds) * (frequency * seconds + 1);
  }

  double derivative(double frequency) {
    if (ratio >= 1) {
      return math.exp(-frequency * seconds) *
          (-frequency * (seconds * seconds));
    }
    final delta = frequency * ratio * seconds,
        e = ratio * ratio * frequency * frequency * seconds,
        factor = -envelope(frequency) + .001 > 0 ? -1 : 1;
    return factor * ((-e * math.exp(-delta))) / angular(frequency * frequency);
  }

  var frequency = 5 / seconds;
  for (var i = 1; i < 12; i++) {
    frequency = frequency - envelope(frequency) / derivative(frequency);
  }
  if (frequency.isNaN) {
    return (stiffness: 100, damping: 10, duration: seconds * 1000);
  }
  final stiffness = frequency * frequency;
  return (
    stiffness: stiffness,
    damping: ratio * 2 * math.sqrt(stiffness),
    duration: seconds * 1000,
  );
}
