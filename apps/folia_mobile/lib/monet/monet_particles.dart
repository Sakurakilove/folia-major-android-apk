import 'dart:math' as math;

import 'package:flutter/material.dart';

// Original ten seeded petal trajectories, durations, delays and per-segment easing, painted natively.
class MonetParticles extends CustomPainter {
  MonetParticles(this.seconds, Listenable frames) : super(repaint: frames);
  final double Function() seconds;
  static final _petal = Path()
    ..moveTo(12, 3)
    ..cubicTo(14.5, 5.5, 16.8, 9, 16, 14)
    ..cubicTo(15.2, 19, 13.5, 21, 12, 21)
    ..cubicTo(10.5, 21, 8.8, 19, 8, 14)
    ..cubicTo(7.2, 9, 9.5, 5.5, 12, 3)
    ..close();
  @override
  void paint(Canvas canvas, Size size) {
    final now = seconds();
    for (var i = 0; i < 10; i++) {
      final reverse = i.isEven,
          duration = 20 + (i * 71) % 20,
          delay = ((i * 41) % 80) / 10;
      final phase = math.max(0.0, now - delay) % duration / duration * 4;
      final index = math.min(3, phase.floor()),
          t = Curves.easeInOut.transform(phase - index);
      final xs = reverse ? [15.0, -25, 10, -20, 15] : [-15.0, 25, -10, 20, -15];
      final ys = reverse ? [-40.0, 60, -20, 40, -40] : [40.0, -60, 20, -40, 40];
      final rotations = [
        0.0,
        reverse ? -120.0 : 120,
        reverse ? -60.0 : 60,
        reverse ? -180.0 : 180,
        0.0,
      ];
      const alphas = [.6, 1.2, 1.0, 1.3, .7];
      final x = uiLerp(xs[index], xs[index + 1], t),
          y = uiLerp(ys[index], ys[index + 1], t);
      final angle =
          ((i * 97) % 360 + uiLerp(rotations[index], rotations[index + 1], t)) *
          math.pi /
          180;
      final scale = (46 + (i * 53) % 40) / 24;
      final alpha =
          (.06 + ((i * 31) % 12) / 100) *
          uiLerp(alphas[index], alphas[index + 1], t);
      canvas.save();
      canvas.translate(
        size.width * (((i * 127 + 43) % 80) + 10) / 100 + x,
        size.height * (((i * 211 + 17) % 80) + 5) / 100 + y,
      );
      canvas.translate(12 * scale, 12 * scale);
      canvas.rotate(angle);
      canvas.translate(-12 * scale, -12 * scale);
      canvas.scale(scale);
      canvas.drawPath(
        _petal,
        Paint()..color = const Color(0xff89aab3).withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  double uiLerp(num a, num b, double t) => a + (b - a) * t;
  @override
  bool shouldRepaint(covariant MonetParticles old) => false;
}
