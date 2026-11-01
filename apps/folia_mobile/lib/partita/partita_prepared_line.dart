import 'dart:ui' as ui;

import '../lyrics/lyric_types.dart';
import '../rendering/folia_typography.dart';
import '../rendering/word_coloring.dart';
import '../theme/folia_theme.dart';
import '../visualizer/glow_word/glow_word_preparation.dart';
import '../visualizer/glow_word/glow_word_timing.dart';
import '../visualizer/subtitles/subtitle_overlay_model.dart';
import 'partita_layout_models.dart';
import 'partita_word_layout.dart';

// Chunk geometry and drawing share source displayWords; no new segmentation or media identity is introduced by the renderer.
class PreparedPartitaChunk {
  const PreparedPartitaChunk(this.layout, this.words, this.activeGuideCss);
  final PartitaChunkLayout layout;
  final PreparedGlowWords words;
  final String activeGuideCss;
}

class PartitaPreparedLine {
  const PartitaPreparedLine(this.line, this.layout, this.chunks);
  final LyricLine line;
  final PartitaLayout layout;
  final List<List<PreparedPartitaChunk>> chunks;
  int get rasterBytes =>
      chunks.expand((c) => c).fold(0, (n, c) => n + c.words.rasterBytes);
  void dispose() {
    for (final chunk in chunks.expand((c) => c)) {
      chunk.words.dispose();
    }
  }
}

Future<PartitaPreparedLine> preparePartitaLine({
  required LyricLine line,
  required PartitaLayout layout,
  required FoliaTheme theme,
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
  final sizes = partitaFontSizes(layout.totalGraphemes, lyricsFontScale),
      profile = GlowWordRenderProfile(line);
  final px = resolveSubtitleClampPx(sizes.main, viewportWidth),
      columns = <List<PreparedPartitaChunk>>[];
  final owned = <PreparedGlowWords>[];
  try {
    for (final column in layout.columns) {
      final chunks = <PreparedPartitaChunk>[];
      for (final chunk in column.chunks) {
        final words = await prepareGlowWords(
          displayWords: chunk.displayWords,
          configs: buildPartitaWordConfigs(chunk, theme.animationIntensity),
          profile: profile,
          theme: theme,
          font: font,
          fontPx: px,
          dpr: dpr,
          resolveColor: resolveColor,
          random: random,
          chorus: line.isChorus,
          stillWanted: stillWanted,
        );
        owned.add(words);
        final active = resolveWordColor(
          chunk.displayWords.map((w) => w.text).join(' '),
          theme.wordColors,
          theme.accentColor,
        );
        chunks.add(PreparedPartitaChunk(chunk, words, active));
      }
      columns.add(List.unmodifiable(chunks));
    }
    final result = PartitaPreparedLine(
      line,
      layout,
      List.unmodifiable(columns),
    );
    owned.clear();
    return result;
  } finally {
    for (final words in owned) {
      words.dispose();
    }
  }
}
