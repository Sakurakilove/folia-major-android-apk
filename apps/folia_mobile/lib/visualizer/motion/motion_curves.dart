import 'package:flutter/animation.dart';

import 'bezier.dart';

// A property uses its original JS or compositor curve explicitly; Flutter's coarser Cubic solver is not the comparison oracle.
class MotionBezierCurve extends Curve {
  const MotionBezierCurve(this.x1, this.y1, this.x2, this.y2);
  final double x1, y1, x2, y2;
  @override
  double transformInternal(double t) => motionBezier(x1, y1, x2, y2, t);
}

class CssBezierCurve extends Curve {
  const CssBezierCurve(this.x1, this.y1, this.x2, this.y2);
  final double x1, y1, x2, y2;
  @override
  double transformInternal(double t) => cssBezier(x1, y1, x2, y2, t);
}
