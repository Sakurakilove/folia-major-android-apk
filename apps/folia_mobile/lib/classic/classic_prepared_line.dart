import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../lyrics/lyric_types.dart';
import '../rendering/folia_typography.dart';
import '../rendering/word_coloring.dart';
import '../theme/folia_theme.dart';
import '../visualizer/glow_word/glow_word_glyphs.dart';
import '../visualizer/glow_word/glow_word_motion.dart';
import '../visualizer/glow_word/glow_word_timing.dart';
import '../visualizer/motion/color_value.dart';
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
        throw const ClassicPreparationCancelled();
      }
      final active = resolveWordColor(
        displayWords[i].text,
        theme.wordColors,
        theme.accentColor,
      );
      final motion = GlowWordMotion(
        word: displayWords[i],
        profile: profile,
        config: layout.words[i],
        intensity: theme.animationIntensity,
        baseColor: base,
        activeColor: color(active),
        baseColorAnimatable: MotionRgba.parse(theme.primaryColor) != null,
        activeColorAnimatable: MotionRgba.parse(active) != null,
        baseColorKey: theme.primaryColor,
        activeColorKey: active,
        rippleScale: 1.5 + random() * 2,
        chorus: line.isChorus,
        enableWordRotation: tuning.enableWordRotation,
      );
      words.add(motion);
      glyphs.add(await GlowWordGlyphs.prepare(motion, font, px, dpr));
    }
    if (stillWanted != null && !stillWanted()) {
      throw const ClassicPreparationCancelled();
    }
    final result = ClassicPreparedLine(
      line,
      layout,
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

class ClassicPreparationCancelled implements Exception {
  const ClassicPreparationCancelled();
}
