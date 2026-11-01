import '../motion/scalar_value.dart';

// AnimatePresence keeps a fading ripple while its scale animation continues; the per-word random target survives status changes.
class GlowWordRipple {
  GlowWordRipple(double target, double now) {
    scale.animate('scale', target, _transition, now);
    opacity.animate('opacity', 0, _transition, now, css: true);
  }
  static const _transition = {'duration': .5, 'ease': 'easeOut'};
  final scale = MotionScalarValue(.2), opacity = MotionScalarValue(.8);
  bool exiting = false;
  bool get isAnimating => scale.isAnimating || opacity.isAnimating;
  bool get retired => exiting && !opacity.isAnimating;
  void leave(double now) {
    exiting = true;
    opacity.animate('opacity', 0, _transition, now, css: true);
  }

  void advance(double now) {
    scale.advance(now);
    opacity.advance(now);
  }
}
