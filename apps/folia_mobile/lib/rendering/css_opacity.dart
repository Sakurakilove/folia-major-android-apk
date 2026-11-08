import 'dart:ui' as ui;

// CSS's floating opacity is an alpha multiplication on the completed group, without packing the animation value into an 8-bit OpacityLayer.
ui.ColorFilter cssOpacityFilter(double alpha) => ui.ColorFilter.matrix([
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  alpha,
  0,
]);
