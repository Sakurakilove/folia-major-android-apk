import 'css_easing.dart';
import 'easing.dart';
import 'keyframes.dart';

// WAAPI applies a single easing to the whole animation before offsets; an easing array instead belongs to each keyframe.
class MotionCssKeyframes {
  MotionCssKeyframes(
    List<double> values, {
    this.duration = 300,
    List<double>? times,
    dynamic ease = 'easeOut',
  }) {
    final perKeyframe = ease is List && (ease.isEmpty || ease.first is! num);
    _outerEase = perKeyframe ? (p) => p : cssMotionEasing(ease);
    _interpolator = MotionKeyframes(
      values,
      duration: duration,
      times: times,
      ease: perKeyframe ? cssMotionKeyframeEase(ease) : 'linear',
    );
  }
  final double duration;
  late final MotionEasing _outerEase;
  late final MotionKeyframes _interpolator;
  double x(double milliseconds) => _interpolator.x(
    duration <= 0
        ? duration
        : _outerEase((milliseconds / duration).clamp(0.0, 1.0)) * duration,
  );
}
