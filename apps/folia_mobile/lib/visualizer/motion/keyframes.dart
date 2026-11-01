import 'dart:math' as math;

import 'easing.dart';

// Numeric branch of Motion keyframes/interpolate, including timing arrays and one easing per segment; caller supplies milliseconds.
class MotionKeyframes {
  MotionKeyframes(
    List<double> values, {
    this.duration = 300,
    List<double>? times,
    dynamic ease = 'easeInOut',
  }) {
    if (values.isEmpty) throw ArgumentError('A keyframe list cannot be empty');
    _values = List.of(values);
    final easingArray = ease is List && (ease.isEmpty || ease.first is! num),
        singleEase = easingArray ? null : motionEasing(ease);
    _fastTwo =
        values.length == 2 &&
        !easingArray &&
        (times == null || times.length != 2 || times[0] == 0 && times[1] == 1);
    _times = times != null && times.length == values.length
        ? times.map((t) => t * duration).toList()
        : [
            for (var i = 0; i < values.length; i++)
              values.length == 1 ? 0 : i / (values.length - 1) * duration,
          ];
    _zeroDelta = values.length > 1 && _times[0] == _times[1];
    if (_times.first > _times.last) {
      _times = _times.reversed.toList();
      _values = _values.reversed.toList();
    }
    _easing = [
      for (var i = 0; i < values.length - 1; i++)
        singleEase ??
            (i < (ease as List).length && ease[i] != null
                ? motionEasing(ease[i])
                : (double p) => p),
    ];
  }
  final double duration;
  late List<double> _values, _times;
  late final List<MotionEasing> _easing;
  late final bool _fastTwo, _zeroDelta;
  double x(double milliseconds) {
    if (_values.length == 1) return _values.first;
    if (_fastTwo) {
      if (_values[0] == _values[1]) return _values[1];
      final t = duration > 0 ? (milliseconds / duration).clamp(0.0, 1.0) : 1.0;
      return _values[0] + (_values[1] - _values[0]) * _easing[0](t);
    }
    final t = math.max(_times.first, math.min(_times.last, milliseconds));
    if (_zeroDelta && t < _times[0]) return _values[0];
    var i = 0;
    for (; i < _times.length - 2; i++) {
      if (t < _times[i + 1]) break;
    }
    final span = _times[i + 1] - _times[i],
        progress = span == 0 ? 1.0 : (t - _times[i]) / span;
    return _values[i] + (_values[i + 1] - _values[i]) * _easing[i](progress);
  }

  bool isDone(double milliseconds) => milliseconds >= duration;
}
