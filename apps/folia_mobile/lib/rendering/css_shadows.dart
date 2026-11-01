import 'dart:math' as math;

import 'package:flutter/painting.dart';

// CSS shadow blur uses sigma = radius/2; Flutter's Shadow radius API has a different radius-to-sigma mapping.
double cssShadowRadius(double radius) =>
    radius <= 0 ? 0 : math.max(0, (radius / 2 - .5) / .57735);
BoxShadow cssBoxShadow(
  Color color,
  Offset offset,
  double radius, {
  double spread = 0,
}) => BoxShadow(
  color: color,
  offset: offset,
  blurRadius: cssShadowRadius(radius),
  spreadRadius: spread,
);
Shadow cssTextShadow(Color color, Offset offset, double radius) =>
    Shadow(color: color, offset: offset, blurRadius: cssShadowRadius(radius));
