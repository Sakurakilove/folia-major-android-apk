import 'package:flutter/widgets.dart';

import '../../visualizer/motion/motion_curves.dart';

// Original per-element entrance tracks share a clock but retain their own delay, duration and transform origin.
class MonetEntrance extends StatelessWidget {
  const MonetEntrance({
    super.key,
    required this.clock,
    required this.duration,
    required this.delay,
    required this.child,
    this.offset = Offset.zero,
    this.scale = 1,
    this.rotation = 0,
    this.curve = const MotionBezierCurve(.25, 1, .5, 1),
    this.opacityCurve = const CssBezierCurve(.25, 1, .5, 1),
    this.scaleYOnly = false,
    this.fade = true,
    this.origin = Alignment.center,
  });
  final AnimationController clock;
  final double duration, delay, scale, rotation;
  final Offset offset;
  final Widget child;
  final Curve curve, opacityCurve;
  final bool scaleYOnly, fade;
  final Alignment origin;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: clock,
    child: child,
    builder: (context, child) {
      final time = clock.value * clock.duration!.inMicroseconds / 1e6;
      final progress = curve.transform(
        ((time - delay) / duration).clamp(0.0, 1.0),
      );
      final size = scale + (1 - scale) * progress;
      return Opacity(
        opacity: fade
            ? opacityCurve.transform(
                ((time - delay) / duration).clamp(0.0, 1.0),
              )
            : 1,
        child: Transform.translate(
          offset: offset * (1 - progress),
          child: Transform.rotate(
            angle: rotation * (1 - progress),
            alignment: origin,
            child: Transform.scale(
              scaleX: scaleYOnly ? 1 : size,
              scaleY: size,
              alignment: origin,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
