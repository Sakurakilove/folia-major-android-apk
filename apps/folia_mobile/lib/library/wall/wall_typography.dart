import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

// Wall typography inherits index.css's body stack, independently of the currently selected lyric style/theme font.
class WallTypography {
  const WallTypography({
    this.fontsEpoch = 0,
    this.locale,
    this.direction = ui.TextDirection.ltr,
  });
  final int fontsEpoch;
  final ui.Locale? locale;
  final ui.TextDirection direction;
  TextStyle style(
    double px, {
    required Color color,
    int weight = 400,
    double height = 1.5,
    double tracking = 0,
    bool tabular = false,
  }) => TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: const [
      'Noto Sans CJK SC',
      'Source Han Sans SC',
      'PingFang SC',
      'Hiragino Sans GB',
      'Microsoft YaHei',
      'Noto Sans JP',
      'Source Han Sans JP',
      'sans-serif',
    ],
    color: color,
    fontSize: px,
    fontWeight: FontWeight.values[((weight - 100) / 100).round().clamp(0, 8)],
    fontVariations: [ui.FontVariation('wght', weight.toDouble())],
    fontFeatures: tabular ? const [ui.FontFeature.tabularFigures()] : null,
    height: height,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: tracking * px,
    wordSpacing: 0,
    locale: locale,
  );
}
