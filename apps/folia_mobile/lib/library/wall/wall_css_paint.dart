import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

// CSS gradient angles depend on the box aspect ratio. Canvas endpoints keep the original 145-degree geometry on every poster shape.
ui.Shader wallLinearGradient(
  Rect bounds,
  double degrees,
  List<Color> colors, {
  List<double>? stops,
}) {
  final radians = degrees * math.pi / 180,
      dx = math.sin(radians),
      dy = -math.cos(radians),
      length = bounds.width * dx.abs() + bounds.height * dy.abs(),
      half = Offset(dx * length / 2, dy * length / 2);
  return ui.Gradient.linear(
    bounds.center - half,
    bounds.center + half,
    colors,
    stops,
  );
}

// Theme color-mix(in srgb,...) is premultiplied by alpha. No early integer-channel rounding or perceptual color interpolation is introduced.
Color wallSrgbMix(Color first, Color second, double secondPart) {
  final p = secondPart, alpha = first.a * (1 - p) + second.a * p;
  if (alpha == 0) return const Color(0x00000000);
  double mix(double a, double b) =>
      (a * first.a * (1 - p) + b * second.a * p) / alpha;
  return Color.from(
    alpha: alpha,
    red: mix(first.r, second.r),
    green: mix(first.g, second.g),
    blue: mix(first.b, second.b),
  );
}

Color wallCssHsl(double hue, double saturation, double lightness) {
  final h = ((hue % 360) + 360) % 360 / 60,
      chroma = (1 - (2 * lightness - 1).abs()) * saturation,
      x = chroma * (1 - ((h % 2) - 1).abs()),
      match = lightness - chroma / 2;
  final (r, g, b) = switch (h) {
    < 1 => (chroma, x, 0.0),
    < 2 => (x, chroma, 0.0),
    < 3 => (0.0, chroma, x),
    < 4 => (0.0, x, chroma),
    < 5 => (x, 0.0, chroma),
    _ => (chroma, 0.0, x),
  };
  return Color.from(
    alpha: 1,
    red: r + match,
    green: g + match,
    blue: b + match,
  );
}

List<Color> wallFallbackColors(String id) {
  var sum = 0;
  // The source spreads by Unicode code point but calls charCodeAt(0) on each piece: supplementary characters contribute only their high surrogate.
  for (var i = 0; i < id.length; i++) {
    final unit = id.codeUnitAt(i);
    sum += unit;
    if (unit >= 0xd800 &&
        unit <= 0xdbff &&
        i + 1 < id.length &&
        id.codeUnitAt(i + 1) >= 0xdc00 &&
        id.codeUnitAt(i + 1) <= 0xdfff) {
      i++;
    }
  }
  final hue = (sum % 360).toDouble();
  return [wallCssHsl(hue, .68, .58), wallCssHsl((hue + 52) % 360, .62, .18)];
}

// Inset shadows are cut out of an inverse mask, not painted as an outer shadow or a replacement border. Padding bounds exclude the element's own border.
void paintWallInsetShadow(
  Canvas canvas,
  Rect paddingBounds,
  Color color, {
  double blur = 0,
  double spread = 0,
  Offset offset = Offset.zero,
}) {
  if (color.a <= 0 || paddingBounds.isEmpty) return;
  final sigma = blur / 2,
      outer = paddingBounds.inflate(
        6 * sigma + spread.abs() + offset.distance + 1,
      ),
      hole = paddingBounds.shift(offset).deflate(spread),
      path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(outer);
  if (!hole.isEmpty) path.addRect(hole);
  final paint = Paint()..color = color;
  if (sigma > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
  canvas.save();
  canvas.clipRect(paddingBounds);
  canvas.drawPath(path, paint);
  canvas.restore();
}
