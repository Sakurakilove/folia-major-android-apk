import 'dart:math' as math;

import '../lyrics/lyric_types.dart';
import '../rendering/js_number.dart';
import 'classic_tuning.dart';
import '../visualizer/glow_word/glow_word_variants.dart';

// Original deterministic Classic geometry, kept separate from semantic word preparation and native font measurement.
class ClassicWordConfig implements GlowWordGeometry {
  const ClassicWordConfig({
    required this.id,
    required this.x,
    required this.y,
    required this.rotate,
    required this.scale,
    required this.marginRight,
    required this.alignSelf,
    required this.passedRotate,
  });
  final String id, marginRight, alignSelf;
  @override
  final double x;
  @override
  final double y;
  @override
  final double rotate;
  @override
  final double scale;
  @override
  final double passedRotate;
  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'rotate': rotate,
    'scale': scale,
    'marginRight': marginRight,
    'alignSelf': alignSelf,
    'passedRotate': passedRotate,
  };
}

class ClassicLineLayout {
  const ClassicLineLayout(
    this.justifyContent,
    this.alignItems,
    this.perspective,
    this.words,
  );
  final String? justifyContent, alignItems;
  final double perspective;
  final List<ClassicWordConfig> words;
  Map<String, dynamic> toJson() => {
    'wordConfigs': words.map((word) => word.toJson()).toList(),
    'lineConfig': {
      if (justifyContent != null) 'justifyContent': justifyContent,
      if (alignItems != null) 'alignItems': alignItems,
      'perspective': perspective,
    },
  };
}

ClassicLineLayout buildClassicLineLayout({
  required LyricLine? line,
  required List<LyricWord> displayWords,
  required String intensity,
  required ClassicTuning tuning,
  required double lyricsFontScale,
  required double viewportWidth,
  required double Function(String text, double fontPx) measureWord,
}) {
  if (line == null) {
    return const ClassicLineLayout('center', 'center', 1000, []);
  }
  final seed = line.start,
      chaotic = intensity == 'chaotic',
      calm = intensity == 'calm',
      interlude = line.text == '......';
  final justify = calm
      ? const ['justify-center']
      : const [
          'justify-start',
          'justify-center',
          'justify-end',
          'justify-around',
          'justify-between',
        ];
  final align = calm
      ? const ['items-center']
      : const ['items-start', 'items-center', 'items-end'];
  final font = math.max(
    2.25 * lyricsFontScale * 16,
    math.min(
      6 * lyricsFontScale * viewportWidth / 100,
      4.5 * lyricsFontScale * 16,
    ),
  );
  final widths = [
    for (final word in displayWords) measureWord(word.text, font),
  ];
  final spread = chaotic
          ? 60.0
          : calm
          ? 0.0
          : 20.0,
      rotation = chaotic
          ? 30.0
          : calm
          ? 0.0
          : 5.0;
  double random(double wordSeed, int offset) {
    final x = math.sin(wordSeed + offset) * 10000;
    return x - x.floor();
  }

  final words = <ClassicWordConfig>[];
  for (var i = 0; i < displayWords.length; i++) {
    final wordSeed = seed + i,
        id = '${displayWords[i].text}-$i-${jsNumberString(seed)}';
    double rng(int offset) => random(wordSeed, offset);
    if (interlude) {
      words.add(
        ClassicWordConfig(
          id: id,
          x: 0,
          y: (rng(2) - .5) * 15,
          rotate: 0,
          scale: 1.5,
          marginRight: '3rem',
          alignSelf: 'center',
          passedRotate: 0,
        ),
      );
      continue;
    }
    final scale = chaotic ? .8 + rng(4) * .6 : 1.1 + rng(4) * .2,
        x = (rng(1) - .5) * spread * 2,
        y = (rng(2) - .5) * spread * 2;
    var margin = chaotic ? '${jsNumberString(rng(5) * 1.5)}rem' : '0.8rem';
    if (!tuning.useLegacyLayout) {
      double nextWidth = 0, nextScale = 1, nextX = 0;
      if (i + 1 < displayWords.length) {
        final nextSeed = seed + (i + 1);
        final configScale = chaotic
            ? .8 + random(nextSeed, 4) * .6
            : 1.1 + random(nextSeed, 4) * .2;
        nextScale = configScale * 1.4;
        nextX = (random(nextSeed, 1) - .5) * spread * 2;
        nextWidth = widths[i + 1];
      }
      final calculated =
          (widths[i] * (scale * 1.4 - 1) / 2 +
              nextWidth * (nextScale - 1) / 2 +
              (x - nextX) +
              .05 * font) *
          tuning.wordSpacing;
      final minimum = (chaotic ? .08 * font : .12 * font) * tuning.wordSpacing;
      margin = '${math.max(minimum, calculated).toStringAsFixed(1)}px';
    }
    words.add(
      ClassicWordConfig(
        id: id,
        x: x,
        y: y,
        rotate: tuning.enableWordRotation ? (rng(3) - .5) * rotation * 2 : 0,
        scale: scale,
        marginRight: margin,
        alignSelf: chaotic && rng(6) > .7
            ? rng(7) > .5
                  ? 'flex-start'
                  : 'flex-end'
            : 'auto',
        passedRotate: tuning.enableWordRotation ? (rng(8) - .5) * 45 : 0,
      ),
    );
  }
  String? selected(List<String> values, double index) {
    final position = index.remainder(values.length).floor();
    return position >= 0 && position < values.length ? values[position] : null;
  }

  return ClassicLineLayout(
    interlude ? 'justify-center' : selected(justify, seed),
    selected(align, seed * 2),
    chaotic ? 500 + seed.remainder(500) : 1000,
    List.unmodifiable(words),
  );
}
