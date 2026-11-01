import 'dart:math' as math;

// Original GlowWord layout/body variants are resolved on word state changes, not rebuilt on every frame.
abstract interface class GlowWordGeometry {
  double get x;
  double get y;
  double get rotate;
  double get scale;
  double get passedRotate;
}

double _or(double? value, double fallback) =>
    value == null || value == 0 || value.isNaN ? fallback : value;

Map<String, dynamic> glowWordLayoutVariant(
  String state,
  GlowWordGeometry config, {
  required String intensity,
  bool enableWordRotation = true,
}) => switch (state) {
  'waiting' => {
    'opacity': 0,
    'scale': .5,
    'x': config.x + math.sin(config.y) * 100,
    'y': config.y + math.cos(config.x) * 50,
    'rotate': enableWordRotation ? config.rotate + 20 : 0,
    'transition': {'duration': .4},
  },
  'active' => {
    'opacity': 1,
    'scale': config.scale.isNaN ? 1.5 : config.scale * 1.4,
    'x': config.x,
    'y': config.y,
    'rotate': config.rotate,
    'transition': {
      'type': 'spring',
      'stiffness': 200,
      'damping': 20,
      'opacity': {'duration': .1},
    },
  },
  'passed' => {
    'opacity': intensity == 'chaotic' ? .9 : .82,
    'scale': _or(config.scale, 1),
    'x': config.x,
    'y': config.y,
    'rotate': config.rotate + config.passedRotate,
    'transition': {
      'duration': .5,
      'rotate': {'duration': 5, 'ease': 'linear'},
    },
  },
  _ => throw ArgumentError.value(state, 'state'),
};

Map<String, dynamic> glowWordBodyVariant(
  String state, {
  required String baseColor,
  required String activeColor,
  double? duration,
  String? wordRevealMode,
}) => switch (state) {
  'waiting' => {
    'color': baseColor,
    'filter': 'blur(10px)',
    'transition': {'duration': .4},
  },
  'active' => {
    'color': activeColor,
    'filter': 'none',
    'transition': {
      'color': {'duration': _or(duration, .2), 'ease': 'linear'},
      'filter': {
        'type': 'tween',
        'duration': wordRevealMode == 'instant'
            ? .08
            : wordRevealMode == 'fast'
            ? .12
            : .2,
      },
    },
    'transitionEnd': {'filter': 'none'},
  },
  'passed' => {
    'color': baseColor,
    'filter': 'blur(0px)',
    'transition': {
      'color': {
        'duration': wordRevealMode == 'instant'
            ? .12
            : wordRevealMode == 'fast'
            ? .24
            : .8,
        'ease': 'easeInOut',
      },
      'filter': {
        'duration': wordRevealMode == 'instant'
            ? .12
            : wordRevealMode == 'fast'
            ? .2
            : .5,
      },
    },
    'transitionEnd': {'filter': 'none'},
  },
  _ => throw ArgumentError.value(state, 'state'),
};
