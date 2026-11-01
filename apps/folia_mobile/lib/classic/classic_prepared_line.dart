import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../lyrics/lyric_types.dart';
import '../rendering/folia_typography.dart';
import '../theme/folia_theme.dart';
import '../visualizer/glow_word/glow_word_glyphs.dart';
import '../visualizer/glow_word/glow_word_motion.dart';
import '../visualizer/glow_word/glow_word_timing.dart';
import '../visualizer/glow_word/glow_word_preparation.dart';
import '../visualizer/subtitles/subtitle_overlay_model.dart';
import 'classic_layout.dart';
import 'classic_tuning.dart';

// Prepare the source word geometry and native draw inputs together; semantic displayWords are mandatory, never replaced with graphemes.
class ClassicPreparedLine {
  ClassicPreparedLine(this.line, this.layout, this.words, this.glyphs);
  final LyricLine line;
  final ClassicLineLayout layout;
  final List<GlowWordMotion> words;
  final List<GlowWordGlyphs> glyphs;
  int get bytes => glyphs.fold(0, (n, g) => n + g.bytes);
  void dispose() {
    for (final glyph in glyphs) {
      glyph.dispose();
    }
  }
}

Future<ClassicPreparedLine> prepareClassicLine({
  required LyricLine line,
  required List<LyricWord> displayWords,
  required FoliaTheme theme,
  required ClassicTuning tuning,
  required double viewportWidth,
  required double dpr,
  required ui.Color Function(String) resolveColor,
  required double Function() random,
  double lyricsFontScale = 1,
  int fontsEpoch = 0,
  ui.Locale? locale,
  bool Function()? stillWanted,
}) async {
  final font = FoliaTypography.fromTheme(
    theme,
    fallbackWeight: 700,
    height: 1.22,
    fontsEpoch: fontsEpoch,
    locale: locale,
  );
  final layout = buildClassicLineLayout(
    line: line,
    displayWords: displayWords,
    intensity: theme.animationIntensity,
    tuning: tuning,
    lyricsFontScale: lyricsFontScale,
    viewportWidth: viewportWidth,
    measureWord: (text, px) {
      // Canvas measureText replaces ASCII segment whitespace one-for-one; the visible CSS word separately collapses it.
      final p = TextPainter(
        text: TextSpan(
          text: text.replaceAll(RegExp(r'[\t\n\r\f]'), ' '),
          style: font.style(px),
        ),
        textDirection: font.direction,
        locale: font.locale,
      )..layout();
      try {
        return p.width;
      } finally {
        p.dispose();
      }
    },
  );
  final sourceSize =
      'clamp(${(2.25 * lyricsFontScale).toStringAsFixed(3)}rem, ${(6 * lyricsFontScale).toStringAsFixed(3)}vw, ${(4.5 * lyricsFontScale).toStringAsFixed(3)}rem)';
  final px = resolveSubtitleClampPx(sourceSize, viewportWidth),
      profile = GlowWordRenderProfile(line);
  final prepared = await prepareGlowWords(
    displayWords: displayWords,
    configs: layout.words,
    profile: profile,
    theme: theme,
    font: font,
    fontPx: px,
    dpr: dpr,
    resolveColor: resolveColor,
    random: random,
    chorus: line.isChorus,
    enableWordRotation: tuning.enableWordRotation,
    stillWanted: stillWanted,
  );
  return ClassicPreparedLine(line, layout, prepared.words, prepared.glyphs);
}

typedef ClassicPreparationCancelled = GlowPreparationCancelled;
