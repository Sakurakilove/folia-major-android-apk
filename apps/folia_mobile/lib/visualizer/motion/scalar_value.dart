import 'dart:math' as math;

import 'css_keyframes.dart';
import 'keyframes.dart';
import 'physical_spring.dart';
import 'spring_options.dart';
import 'value_options.dart';

const _unsetVariant = Object();

// Finite numeric property animation and MotionValue's observed-frame velocity; a scene owns vsync, never one ticker per property.
class MotionScalarValue {
  MotionScalarValue(this.value, {dynamic variantTarget = _unsetVariant})
    : _variantTarget = identical(variantTarget, _unsetVariant)
          ? value
          : variantTarget;
  double value, _updatedAt = 0;
  dynamic _variantTarget;
  double? _previousValue, _previousAt;
  _ScalarAnimation? _animation;
  bool get isAnimating => _animation != null;
  static bool _same(dynamic a, dynamic b) {
    if (a is! List || b is! List) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_same(a[i], b[i])) return false;
    }
    return true;
  }

  void seedVariant(dynamic target) => _variantTarget = target;
  // React variants only animate changed resolved targets. A new status must not restart an unchanged x/y spring.
  void animateVariant(
    String key,
    dynamic target,
    Map<String, dynamic> transition,
    double now, {
    bool css = false,
    dynamic identity = _unsetVariant,
  }) {
    final next = identical(identity, _unsetVariant) ? target : identity;
    if (_same(_variantTarget, next)) return;
    _variantTarget = next is List ? List.of(next) : next;
    animate(key, target, transition, now, css: css);
  }

  double velocity(double now) {
    if (_previousValue == null || now - _updatedAt > 30) return 0;
    final delta = math.min(_updatedAt - _previousAt!, 30.0);
    return delta == 0 ? 0 : (value - _previousValue!) * 1000 / delta;
  }

  void _set(double next, double now) {
    if (_updatedAt != now) {
      _previousValue = value;
      _previousAt = _updatedAt;
    }
    value = next;
    _updatedAt = now;
  }

  // Shared source MotionValue history for follower generators whose analytical trajectory is owned externally.
  void recordObserved(double next, double now) => _set(next, now);

  void jump(double next, double now) {
    _animation = null;
    _set(next, now);
    _previousValue = _previousAt = null;
  }

  void animate(
    String key,
    dynamic target,
    Map<String, dynamic> transition,
    double now, {
    bool css = false,
  }) {
    final frames = target is List
        ? target.map((v) => v == null ? value : (v as num).toDouble()).toList()
        : [value, (target as num).toDouble()];
    final options = resolveMotionValueOptions(
      key,
      frames,
      transition,
      velocity: velocity(now),
    );
    final values = (options['keyframes'] as List)
        .map((v) => (v as num).toDouble())
        .toList();
    if (values.length > 1 &&
        values.every((v) => v == value) &&
        !(options['type'] == 'spring' && options['velocity'] != 0)) {
      jump(value, now);
      return;
    }
    _animation = _ScalarAnimation(values, options, now, css);
    advance(now);
  }

  void advance(double now) {
    final animation = _animation;
    if (animation == null) return;
    _set(animation.x(now), now);
    if (animation.done(now)) _animation = null;
  }
}

class _ScalarAnimation {
  _ScalarAnimation(
    List<double> values,
    Map<String, dynamic> options,
    this.start,
    bool css,
  ) : delay = (options['delay'] as num?)?.toDouble() ?? 0,
      initial = values.first,
      target = values.last {
    if ((options['repeat'] as num? ?? 0) != 0) {
      throw UnsupportedError(
        'Repeated animation must use the repeating timeline backend',
      );
    }
    final duration = (options['duration'] as num?)?.toDouble();
    if (options['type'] == false || duration == 0) {
      _duration = 0;
    } else if (options['type'] == 'spring') {
      _spring = resolveMotionSpring(options).between(initial, target);
    } else {
      _duration = duration ?? 300;
      final ease = options['ease'] ?? 'easeInOut';
      final times = (options['times'] as List?)
          ?.map((t) => (t as num).toDouble())
          .toList();
      if (css) {
        _cssKeyframes = MotionCssKeyframes(
          values,
          duration: _duration,
          times: times,
          ease: ease,
        );
      } else {
        _keyframes = MotionKeyframes(
          values,
          duration: _duration,
          times: times,
          ease: ease,
        );
      }
    }
  }
  final double start, delay, initial, target;
  double _duration = 0;
  MotionPhysicalSpring? _spring;
  MotionKeyframes? _keyframes;
  MotionCssKeyframes? _cssKeyframes;
  double _elapsed(double now) => now - start - delay;
  double x(double now) {
    final elapsed = _elapsed(now);
    if (elapsed < 0) return initial;
    if (_spring != null) return _spring!.x(elapsed / 1000);
    return _cssKeyframes?.x(elapsed) ?? _keyframes?.x(elapsed) ?? target;
  }

  bool done(double now) {
    final elapsed = _elapsed(now);
    return elapsed >= 0 &&
        (_spring?.isDone(elapsed / 1000) ?? elapsed >= _duration);
  }
}
