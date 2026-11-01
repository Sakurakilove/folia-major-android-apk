import 'dart:math' as math;

import '../lyrics/lyric_types.dart';
import 'partita_layout_models.dart';

// The word offsets live inside their chunk; chunk position must not be added again to every word.
List<PartitaWordConfig> buildPartitaWordConfigs(
  PartitaChunkLayout chunk,
  String intensity,
) => [
  for (var i = 0; i < chunk.displayWords.length; i++)
    _wordConfig(chunk.config, chunk.displayWords, i, intensity),
];
PartitaWordConfig _wordConfig(
  PartitaWordConfig parent,
  List<LyricWord> words,
  int i,
  String intensity,
) {
  final seed = words.first.start + i * 7.13,
      calm = intensity == 'calm',
      chaotic = intensity == 'chaotic';
  final spread = chaotic
          ? 15.0
          : calm
          ? 0.0
          : 6.0,
      rotate = chaotic
          ? 8.0
          : calm
          ? 0.0
          : 3.0;
  double random(int offset) {
    final x = math.sin(seed + offset) * 10000;
    return x - x.floor();
  }

  return PartitaWordConfig(
    '${parent.id}-w$i',
    (random(1) - .5) * spread * 2,
    (random(2) - .5) * spread * 2,
    (random(3) - .5) * rotate * 2,
    parent.scale,
    '0',
    'auto',
    (random(8) - .5) * 20,
  );
}

({String main, String empty, String translation, String upcoming})
partitaFontSizes(int graphemes, double scale) {
  final density = graphemes > 40 ? .8 : 1.0;
  String clamp(double a, double b, double c) =>
      'clamp(${(a * scale).toStringAsFixed(3)}rem, ${(b * scale).toStringAsFixed(3)}vw, ${(c * scale).toStringAsFixed(3)}rem)';
  return (
    main: clamp(2.5 * density, 5.5 * density, 4.5 * density),
    empty: clamp(1.2, 2.8, 1.9),
    translation: clamp(1.05, 2.2, 1.2),
    upcoming: clamp(.875, 1.8, 1),
  );
}
