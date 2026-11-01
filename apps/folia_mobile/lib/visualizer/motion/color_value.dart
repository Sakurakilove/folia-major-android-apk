import 'dart:math' as math;

// Motion's explicit-color model: RGB uses square/sqrt mixing, integer output and five-decimal alpha, not Color.lerp.
class MotionRgba {
  const MotionRgba(this.red, this.green, this.blue, [this.alpha = 1]);
  final double red, green, blue, alpha;
  @override
  bool operator ==(Object other) =>
      other is MotionRgba &&
      red == other.red &&
      green == other.green &&
      blue == other.blue &&
      alpha == other.alpha;
  @override
  int get hashCode => Object.hash(red, green, blue, alpha);
  @override
  String toString() => 'rgba($red,$green,$blue,$alpha)';
  static final _numbers = RegExp(r'-?(?:\d+(?:\.\d+)?|\.\d+)');
  static MotionRgba? parse(String value) {
    if (RegExp(r'^#[\da-fA-F]{3,8}$').hasMatch(value)) {
      final hex = value.substring(1), short = hex.length < 5;
      double channel(int i) {
        final s = short ? hex[i] * 2 : hex.substring(i * 2, i * 2 + 2);
        return int.parse(s, radix: 16).toDouble();
      }

      if (![3, 4, 6, 8].contains(hex.length)) return null;
      return MotionRgba(
        channel(0),
        channel(1),
        channel(2),
        hex.length == 4 || hex.length == 8 ? channel(3) / 255 : 1,
      );
    }
    final rgb = value.startsWith('rgb'), hsl = value.startsWith('hsl');
    if ((!rgb && !hsl) || !value.endsWith(')')) return null;
    final values = _numbers
        .allMatches(value)
        .map((m) => double.parse(m[0]!))
        .toList();
    if (values.length < 3 || values.length > 4) return null;
    final a = values.length == 4 ? values[3] : 1.0;
    if (rgb) return MotionRgba(values[0], values[1], values[2], a);
    final hue = values[0] / 360, s = values[1] / 100, l = values[2] / 100;
    if (s == 0) {
      return MotionRgba(
        (l * 255).roundToDouble(),
        (l * 255).roundToDouble(),
        (l * 255).roundToDouble(),
        a,
      );
    }
    final q = l < .5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
    double channel(double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      final v = t < 1 / 6
          ? p + (q - p) * 6 * t
          : t < .5
          ? q
          : t < 2 / 3
          ? p + (q - p) * (2 / 3 - t) * 6
          : p;
      return (v * 255).roundToDouble();
    }

    return MotionRgba(
      channel(hue + 1 / 3),
      channel(hue),
      channel(hue - 1 / 3),
      a,
    );
  }

  MotionRgba withAlpha(double value) => MotionRgba(red, green, blue, value);
  MotionRgba mixed(MotionRgba to, double progress) {
    double channel(double from, double target) {
      final square = from * from + (target * target - from * from) * progress;
      return (square < 0 ? 0.0 : math.sqrt(square))
          .clamp(0, 255)
          .roundToDouble();
    }

    final a = (alpha + (to.alpha - alpha) * progress).clamp(0.0, 1.0);
    return MotionRgba(
      channel(red, to.red),
      channel(green, to.green),
      channel(blue, to.blue),
      (a * 100000).round() / 100000,
    );
  }

  Map<String, double> toJson() => {
    'red': red,
    'green': green,
    'blue': blue,
    'alpha': alpha,
  };
}
