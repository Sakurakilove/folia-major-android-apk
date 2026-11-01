import 'color_value.dart';
import 'scalar_value.dart';

// Resolve and mix once per sampled property; an interrupted color starts from the previous serialized integer-channel value.
class MotionColorValue {
  MotionColorValue(MotionRgba initial, {bool? animatable, Object? variantKey})
    : _from = initial,
      _to = initial,
      value = initial,
      _animatable = animatable ?? true,
      _targetKey = variantKey ?? initial;
  bool _animatable;
  Object _targetKey;
  MotionRgba _from, _to, value;
  final _progress = MotionScalarValue(1);
  bool get isAnimating => _progress.isAnimating;
  void animate(
    String key,
    MotionRgba target,
    Map<String, dynamic> transition,
    double now, {
    bool animatable = true,
    Object? variantKey,
  }) {
    final targetKey = variantKey ?? target;
    if (targetKey == _targetKey) return;
    _targetKey = targetKey;
    _from = value;
    _to = target;
    if (!_animatable || !animatable) {
      _animatable = animatable;
      _progress.jump(1, now);
      value = target;
      return;
    }
    _progress.jump(0, now);
    _progress.animate(key, 1, transition, now);
    advance(now);
  }

  void advance(double now) {
    _progress.advance(now);
    value = _progress.isAnimating ? _from.mixed(_to, _progress.value) : _to;
  }
}
