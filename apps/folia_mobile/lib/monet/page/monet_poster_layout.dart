import 'dart:math' as math;

import '../monet_lyrics_model.dart';
import 'monet_tuning.dart';

// VisualizerMonet.tsx CSS breakpoints, clamps, bleed reservation and font scales; no alternate native layout.
class MonetPosterLayout {
  MonetPosterLayout({
    required this.viewportWidth,
    required this.viewportHeight,
    required double containerWidth,
    required MonetTuning tuning,
    double lyricsFontScale = 1,
    double subtitleFontScale = 1,
  }) {
    scale = resolveMonetLargeScreenScale(
      containerWidth > 0 ? containerWidth : viewportWidth,
    );
    rowWidth = math.min(containerWidth, (1520 * scale).roundToDouble());
    paddingX = viewportWidth >= 1536
        ? 80
        : viewportWidth >= 1024
        ? 56
        : viewportWidth >= 640
        ? 32
        : 20;
    paddingY = viewportWidth >= 1024
        ? 32
        : viewportWidth >= 640
        ? 24
        : 20;
    showPortrait = viewportWidth >= 768;
    portraitPaddingRight = viewportWidth >= 1280
        ? 48
        : viewportWidth >= 1024
        ? 40
        : viewportWidth >= 640
        ? 32
        : 20;
    portraitWidth = showPortrait
        ? (viewportWidth * .28).clamp(220.0, (430 * scale).roundToDouble())
        : 0;
    textWidth = math.max(2 * paddingX, rowWidth - portraitWidth);
    contentWidth = math.max(0, textWidth - paddingX * 2);
    final innerMax = (viewportWidth * .26).clamp(
      210.0,
      (380 * scale).roundToDouble(),
    );
    portraitInnerWidth = math.max(
      0,
      math.min(innerMax, portraitWidth - 12 - portraitPaddingRight),
    );
    final bleed = tuning.portraitStyle == 'square'
        ? math.max(0.0, .35135 * innerMax - 48)
        : 0.0;
    headerWidth = math.min(
      contentWidth,
      math.max(192, contentWidth - bleed - tuning.portraitOffsetX.abs()),
    );
    final fontScale = tuning.fontScale * lyricsFontScale;
    lyricFontPx =
        resolveClampFontPx(1.34, 2.75, 2.28, viewportWidth) * fontScale * scale;
    inactiveFontPx =
        resolveClampFontPx(1.08, 2, 1.48, viewportWidth) * fontScale * scale;
    translationFontPx =
        resolveClampFontPx(.94, 1.28, 1.14, viewportWidth) *
        fontScale *
        subtitleFontScale *
        scale;
    titleFontPx = math.min(
      double.parse((2.8 * scale).toStringAsFixed(3)) * 16,
      math.max(1.45 * 16, viewportWidth * .033),
    );
    artistFontPx = math.min(
      double.parse((1.8 * scale).toStringAsFixed(3)) * 16,
      math.max(16, viewportWidth * .018),
    );
    glowBuffer = (lyricFontPx * 1.2).roundToDouble();
    railWidth = math.min(
      (780 * scale).roundToDouble(),
      contentWidth + glowBuffer * 2,
    );
    railHeight = (viewportHeight * .52).clamp(
      280.0,
      math.max(520 * scale, lyricFontPx * 1.18 * 7).roundToDouble(),
    );
    audioWidth = math.min(450, viewportWidth * .55);
    audioPaddingX = viewportWidth >= 1024
        ? 56
        : viewportWidth >= 640
        ? 32
        : 20;
  }
  final double viewportWidth, viewportHeight;
  late final double scale,
      rowWidth,
      paddingX,
      paddingY,
      portraitPaddingRight,
      portraitWidth,
      textWidth,
      contentWidth,
      portraitInnerWidth,
      headerWidth,
      lyricFontPx,
      inactiveFontPx,
      translationFontPx,
      titleFontPx,
      artistFontPx,
      glowBuffer,
      railWidth,
      railHeight,
      audioWidth,
      audioPaddingX;
  late final bool showPortrait;
}
