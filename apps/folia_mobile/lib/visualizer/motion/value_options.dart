import 'dart:math' as math;

// Source animateMotionValue/getValueTransition/getDefaultTransition option resolution, before the renderer/clock-specific animation backend.
const _transformKeys = {
  'transformPerspective',
  'x',
  'y',
  'z',
  'translateX',
  'translateY',
  'translateZ',
  'scale',
  'scaleX',
  'scaleY',
  'rotate',
  'rotateX',
  'rotateY',
  'rotateZ',
  'skew',
  'skewX',
  'skewY',
  'pathRotation',
};
const _orchestration = {
  'when',
  'delay',
  'delayChildren',
  'staggerChildren',
  'staggerDirection',
  'repeat',
  'repeatType',
  'repeatDelay',
  'from',
  'elapsed',
};
bool _truthy(dynamic value) =>
    value != null &&
    value != false &&
    value != 0 &&
    value != '' &&
    !(value is double && value.isNaN);

Map<String, dynamic> motionValueTransition(
  Map<String, dynamic> transition,
  String key,
) {
  final chosen = transition[key] ?? transition['default'];
  if (chosen == null) return transition;
  final child = Map<String, dynamic>.from(chosen as Map);
  if (_truthy(child['inherit'])) {
    child.remove('inherit');
    return {...transition, ...child};
  }
  return child;
}

Map<String, dynamic> motionDefaultTransition(
  String key,
  List<dynamic> keyframes,
) {
  if (keyframes.length > 2) return {'type': 'keyframes', 'duration': .8};
  if (_transformKeys.contains(key)) {
    if (key.startsWith('scale')) {
      return {
        'type': 'spring',
        'stiffness': 550,
        'damping': keyframes[1] == 0 ? 2 * math.sqrt(550) : 30,
        'restSpeed': 10,
      };
    }
    return {'type': 'spring', 'stiffness': 500, 'damping': 25, 'restSpeed': 10};
  }
  return {
    'type': 'keyframes',
    'ease': [.25, .1, .35, 1],
    'duration': .3,
  };
}

Map<String, dynamic> resolveMotionValueOptions(
  String key,
  List<dynamic> keyframes,
  Map<String, dynamic> transition, {
  double velocity = 0,
}) {
  final value = motionValueTransition(transition, key),
      delay = _truthy(value['delay'])
          ? value['delay'] as num
          : _truthy(transition['delay'])
          ? transition['delay'] as num
          : 0;
  final elapsed = ((transition['elapsed'] as num?) ?? 0) - delay * 1000;
  final options = <String, dynamic>{
    'keyframes': [...keyframes],
    'ease': 'easeOut',
    'velocity': velocity,
    ...value,
    'delay': -elapsed,
  };
  if (!value.keys.any((field) => !_orchestration.contains(field))) {
    options.addAll(motionDefaultTransition(key, keyframes));
  }
  if (_truthy(options['duration'])) {
    options['duration'] = (options['duration'] as num) * 1000;
  }
  if (_truthy(options['repeatDelay'])) {
    options['repeatDelay'] = (options['repeatDelay'] as num) * 1000;
  }
  if (options.containsKey('from')) {
    (options['keyframes'] as List)[0] = options['from'];
  }
  return options;
}
