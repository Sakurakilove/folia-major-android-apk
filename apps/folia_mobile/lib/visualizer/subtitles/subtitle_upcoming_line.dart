import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../rendering/css_text.dart';
import '../motion/motion_curves.dart';

// The original upcoming preview's transition-all duration-500 animates its filter and text properties, not merely visibility.
class SubtitleUpcomingLine extends StatelessWidget {
  const SubtitleUpcomingLine({
    super.key,
    required this.text,
    required this.blur,
    required this.style,
  });
  final String text;
  final bool blur;
  final TextStyle style;
  static const _ease = CssBezierCurve(.4, 0, .2, 1);
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: blur ? 1 : 0, end: blur ? 1 : 0),
    duration: const Duration(milliseconds: 500),
    curve: _ease,
    child: AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 500),
      curve: _ease,
      style: style,
      child: Text(
        cssNormalText(text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: style.fontFamily,
          fontFamilyFallback: style.fontFamilyFallback,
          locale: style.locale,
          height: 1.5,
          letterSpacing: 0,
          wordSpacing: 0,
        ),
      ),
    ),
    builder: (context, sigma, child) => ImageFiltered(
      enabled: sigma > 0,
      imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    ),
  );
}
