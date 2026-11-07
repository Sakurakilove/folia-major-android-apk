import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';

import '../../../wall/wall_css_paint.dart';

// Average/chroma use unrounded bytes; the original rgbToHsl separately rounds each average channel before selecting the integer hue.
enum BravaisArtistToneKind { color, fallback, unavailable }

class BravaisArtistTone {
  const BravaisArtistTone(this.kind, [this.hue]);
  static const fallback = BravaisArtistTone(BravaisArtistToneKind.fallback),
      unavailable = BravaisArtistTone(BravaisArtistToneKind.unavailable);
  final BravaisArtistToneKind kind;
  final int? hue;
  Color? get color =>
      hue == null ? null : wallCssHsl(hue!.toDouble(), .62, .66);
}

BravaisArtistTone resolveBravaisArtistTone(Uint8List pixels) {
  var red = 0.0, green = 0.0, blue = 0.0, count = 0;
  for (var i = 0; i < pixels.length; i += 4) {
    if (pixels[i + 3] < 128) continue;
    red += pixels[i];
    green += pixels[i + 1];
    blue += pixels[i + 2];
    count++;
  }
  if (count == 0) return BravaisArtistTone.fallback;
  red /= count;
  green /= count;
  blue /= count;
  if ((math.max(red, math.max(green, blue)) -
              math.min(red, math.min(green, blue))) /
          255 <
      .04) {
    return BravaisArtistTone.fallback;
  }
  red = red.roundToDouble() / 255;
  green = green.roundToDouble() / 255;
  blue = blue.roundToDouble() / 255;
  final maximum = math.max(red, math.max(green, blue)),
      minimum = math.min(red, math.min(green, blue)),
      delta = maximum - minimum;
  final hue = delta == 0
      ? 0.0
      : maximum == red
      ? ((green - blue) / delta) % 6
      : maximum == green
      ? (blue - red) / delta + 2
      : (red - green) / delta + 4;
  return BravaisArtistTone(
    BravaisArtistToneKind.color,
    (((hue * 60 % 360) + 360) % 360).round(),
  );
}
