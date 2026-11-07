import 'dart:math' as math;
import 'dart:ui' as ui;

import 'css_color_matrices.dart';

double _dot(List<List<double>> matrix, int row, double x, double y, double z) =>
    matrix[row][0] * x + matrix[row][1] * y + matrix[row][2] * z;

// CSS Color 4 uses premultiplied interpolation and D65 Oklab. Keep float channels until actual rasterization, including out-of-gamut intermediates.
ui.Color cssSrgbMix(ui.Color first, ui.Color second, double p) {
  final alpha = first.a * (1 - p) + second.a * p;
  if (alpha == 0) return const ui.Color(0x00000000);
  double mix(double a, double b) =>
      (a * first.a * (1 - p) + b * second.a * p) / alpha;
  return ui.Color.from(
    alpha: alpha,
    red: mix(first.r, second.r),
    green: mix(first.g, second.g),
    blue: mix(first.b, second.b),
    colorSpace: ui.ColorSpace.extendedSRGB,
  );
}

class CssOklab {
  const CssOklab(this.l, this.a, this.b, this.alpha);
  final double l, a, b, alpha;
  factory CssOklab.fromColor(ui.Color color) {
    double linear(double v) => v.abs() <= .04045
        ? v / 12.92
        : v.sign * math.pow((v.abs() + .055) / 1.055, 2.4).toDouble();
    double cubeRoot(double v) =>
        v == 0 ? v : v.sign * math.pow(v.abs(), 1 / 3).toDouble();
    final r = linear(color.r),
        g = linear(color.g),
        b = linear(color.b),
        x = cubeRoot(_dot(cssRgbToLms, 0, r, g, b)),
        y = cubeRoot(_dot(cssRgbToLms, 1, r, g, b)),
        z = cubeRoot(_dot(cssRgbToLms, 2, r, g, b));
    return CssOklab(
      _dot(cssLmsToLab, 0, x, y, z),
      _dot(cssLmsToLab, 1, x, y, z),
      _dot(cssLmsToLab, 2, x, y, z),
      color.a,
    );
  }
  CssOklab mixed(CssOklab to, double p) {
    final nextAlpha = alpha * (1 - p) + to.alpha * p;
    if (nextAlpha == 0) return const CssOklab(0, 0, 0, 0);
    double mix(double from, double target) =>
        (from * alpha * (1 - p) + target * to.alpha * p) / nextAlpha;
    return CssOklab(mix(l, to.l), mix(a, to.a), mix(b, to.b), nextAlpha);
  }

  ui.Color toColor() {
    double cube(double v) => v * v * v;
    double encoded(double v) => v.abs() <= .0031308
        ? v * 12.92
        : v.sign * (1.055 * math.pow(v.abs(), 1 / 2.4).toDouble() - .055);
    final x = cube(_dot(cssLabToLms, 0, l, a, b)),
        y = cube(_dot(cssLabToLms, 1, l, a, b)),
        z = cube(_dot(cssLabToLms, 2, l, a, b));
    return ui.Color.from(
      alpha: alpha,
      red: encoded(_dot(cssLmsToRgb, 0, x, y, z)),
      green: encoded(_dot(cssLmsToRgb, 1, x, y, z)),
      blue: encoded(_dot(cssLmsToRgb, 2, x, y, z)),
      colorSpace: ui.ColorSpace.extendedSRGB,
    );
  }
}

class CssColorValue {
  const CssColorValue.legacy(this.color) : legacy = true;
  const CssColorValue.modern(this.color) : legacy = false;
  final ui.Color color;
  final bool legacy;
  static CssColorValue interpolate(
    CssColorValue from,
    CssColorValue to,
    double p,
  ) => from.legacy && to.legacy
      ? CssColorValue.legacy(cssSrgbMix(from.color, to.color, p))
      : CssColorValue.modern(
          CssOklab.fromColor(from.color)
              .mixed(CssOklab.fromColor(to.color), p)
              .toColor(),
        );
  @override
  bool operator ==(Object other) =>
      other is CssColorValue && color == other.color && legacy == other.legacy;
  @override
  int get hashCode => Object.hash(color, legacy);
}
