import 'dart:ui' as ui;

import '../../lyrics/lyric_types.dart';
import '../../rendering/folia_typography.dart';
import '../../rendering/word_coloring.dart';
import '../../theme/folia_theme.dart';
import '../motion/color_value.dart';
import 'glow_word_glyphs.dart';
import 'glow_word_motion.dart';
import 'glow_word_timing.dart';
import 'glow_word_variants.dart';

// Shared Classic/Partita preparation uses one font/color/timing contract and owns every pending glyph until transfer.
class PreparedGlowWords {
  const PreparedGlowWords(this.words, this.glyphs);
  final List<GlowWordMotion> words;
  final List<GlowWordGlyphs> glyphs;
  int get rasterBytes => glyphs.fold(0, (n, g) => n + g.bytes);
  void dispose() {
    for (final glyph in glyphs) {
      glyph.dispose();
    }
  }
}

Future<PreparedGlowWords> prepareGlowWords({
  required List<LyricWord> displayWords,
  required List<GlowWordGeometry> configs,
  required GlowWordRenderProfile profile,
  required FoliaTheme theme,
  required FoliaTypography font,
  required double fontPx,
  required double dpr,
  required ui.Color Function(String) resolveColor,
  required double Function() random,
  required bool chorus,
  bool enableWordRotation = true,
  bool Function()? stillWanted,
}) async {
  if (displayWords.length != configs.length) {
    throw ArgumentError('Each source word needs its own geometry');
  }
  MotionRgba color(String css) {
    final parsed = MotionRgba.parse(css);
    if (parsed != null) return parsed;
    final c = resolveColor(css);
    return MotionRgba(c.r * 255, c.g * 255, c.b * 255, c.a);
  }

  final base = color(theme.primaryColor),
      words = <GlowWordMotion>[],
      glyphs = <GlowWordGlyphs>[];
  var transferred = false;
  try {
    for (var i = 0; i < displayWords.length; i++) {
      if (stillWanted != null && !stillWanted()) {
        throw const GlowPreparationCancelled();
      }
      final active = resolveWordColor(
        displayWords[i].text,
        theme.wordColors,
        theme.accentColor,
      );
      final motion = GlowWordMotion(
        word: displayWords[i],
        profile: profile,
        config: configs[i],
        intensity: theme.animationIntensity,
        baseColor: base,
        activeColor: color(active),
        baseColorKey: theme.primaryColor,
        activeColorKey: active,
        baseColorAnimatable: MotionRgba.parse(theme.primaryColor) != null,
        activeColorAnimatable: MotionRgba.parse(active) != null,
        rippleScale: 1.5 + random() * 2,
        chorus: chorus,
        enableWordRotation: enableWordRotation,
      );
      words.add(motion);
      glyphs.add(await GlowWordGlyphs.prepare(motion, font, fontPx, dpr));
    }
    if (stillWanted != null && !stillWanted()) {
      throw const GlowPreparationCancelled();
    }
    final result = PreparedGlowWords(
      List.unmodifiable(words),
      List.unmodifiable(glyphs),
    );
    transferred = true;
    return result;
  } finally {
    if (!transferred) {
      for (final glyph in glyphs) {
        glyph.dispose();
      }
    }
  }
}

class GlowPreparationCancelled implements Exception {
  const GlowPreparationCancelled();
}
