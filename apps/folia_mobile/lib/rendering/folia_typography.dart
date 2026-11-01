import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../theme/folia_theme.dart';
import '../theme/font_stacks.dart';

// A shared resolved font specification feeds layout and rasterization, including variable weight and locale.
class FoliaTypography {
  const FoliaTypography({
    required this.families,
    required this.weight,
    required this.height,
    this.fontsEpoch = 0,
    this.locale,
    this.direction = ui.TextDirection.ltr,
  });
  factory FoliaTypography.fromTheme(
    FoliaTheme theme, {
    bool translation = false,
    int fallbackWeight = 600,
    double height = 1.18,
    int fontsEpoch = 0,
    ui.Locale? locale,
  }) => FoliaTypography(
    families: resolveThemeFontFamilies(theme, translation: translation),
    weight: resolveThemeFontWeight(theme, fallbackWeight),
    height: height,
    fontsEpoch: fontsEpoch,
    locale: locale,
  );
  final List<String> families;
  final int weight, fontsEpoch;
  final double height;
  final ui.Locale? locale;
  final ui.TextDirection direction;
  String get cacheKey =>
      '${families.join('\u0001')}|$weight|$height|$fontsEpoch|$locale|$direction';
  FoliaTypography withHeight(double value) => FoliaTypography(
    families: families,
    weight: weight,
    height: value,
    fontsEpoch: fontsEpoch,
    locale: locale,
    direction: direction,
  );

  TextStyle style(
    double px, {
    ui.Color color = const ui.Color(0xffffffff),
  }) => TextStyle(
    fontFamily: families.firstOrNull,
    fontFamilyFallback: families.length > 1 ? families.sublist(1) : const [],
    fontSize: px,
    fontWeight: FontWeight.values[((weight - 100) / 100).round().clamp(0, 8)],
    fontVariations: [ui.FontVariation('wght', weight.toDouble())],
    height: height,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    wordSpacing: 0,
    color: color,
    locale: locale,
  );
}
