import 'package:flutter/painting.dart';

import '../../wall/wall_css_paint.dart';

// Resolved wall.css/bravaisTileKinds.css tokens. Lyric theme colors stay external; this projection does not invent another palette or font theme.
class BravaisCardPalette {
  const BravaisCardPalette({
    required this.background,
    required this.ink,
    required this.accent,
    required this.secondary,
    required this.daylight,
    this.customTint,
    this.tintIntensity = .5,
  });
  final Color background, ink, accent, secondary;
  final Color? customTint;
  final bool daylight;
  final double tintIntensity;
  Color get shade =>
      daylight ? const Color(0xffffffff) : const Color(0xff000000);
  Color get posterBackground =>
      wallSrgbMix(background, ink, daylight ? .06 : .12);
  double get tintOpacity => tintIntensity * (daylight ? .72 : 1);
  List<Color> get tintColors => customTint == null
      ? [
          wallSrgbMix(background, accent, .22),
          wallSrgbMix(background, secondary, .16),
        ]
      : [customTint!, customTint!];
  Color get stackNear => wallSrgbMix(background, ink, daylight ? .2 : .34);
  Color get stackFar => wallSrgbMix(background, ink, daylight ? .12 : .2);
  Color get stackLine => daylight
      ? wallSrgbMix(background, ink, .38)
      : wallSrgbMix(background, const Color(0xff000000), .28);
  Color get stackTint => customTint ?? wallSrgbMix(background, secondary, .16);
  Color get focusHairline =>
      (daylight ? const Color(0xffffffff) : const Color(0xff000000)).withValues(
        alpha: daylight ? .78 : .62,
      );
  Color get outerHairline =>
      (daylight ? const Color(0xffffffff) : const Color(0xff000000)).withValues(
        alpha: daylight ? .45 : .38,
      );
  Color get chromeShadow => shade.withValues(alpha: .55);
  Color stackColor(
    Color base, {
    required double tint,
    required double dim,
    required double alpha,
  }) {
    final color = wallSrgbMix(wallSrgbMix(base, stackTint, tint), shade, dim);
    return color.withValues(alpha: color.a * alpha);
  }
}
