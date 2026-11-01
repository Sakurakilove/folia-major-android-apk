import 'dart:math' as math;

import 'package:characters/characters.dart';

import '../lyrics/lyric_types.dart';
import '../lyrics/semantic_layout.dart';
import '../lyrics/word_segmentation.dart';
import '../rendering/js_number.dart';
import 'partita_layout_models.dart';
import 'partita_tuning.dart';

// Port of the actual buildSequentialColumns path, including its one-column sequence rather than the unused target-column helper.
PartitaLayout buildPartitaLayout(
  LyricLine line,
  String intensity,
  double windowHeight,
  PartitaTuning tuning, {
  required PlainWordSegmenter segmentPlain,
}) {
  final chaotic = intensity == 'chaotic', calm = intensity == 'calm';
  final total = math.max(
    math.max(
      line.text.replaceAll(RegExp(r'\s+'), '').characters.length,
      line.words.length,
    ),
    1,
  );
  final units = buildPostLyricLayoutUnits(
    line,
    segmentPlain: segmentPlain,
    semantic: tuning.useSemanticLayout,
    sticky: true,
  );
  final actualRows = math.min(
    units.length,
    math.max(1, (windowHeight * .65 / 100).floor()),
  );
  var seed = line.start;
  double random() {
    final x = math.sin(seed++) * 10000;
    return x - x.floor();
  }

  final chunks = <List<LyricLayoutUnit>>[];
  var remaining = units.length, remainingChunks = actualRows, index = 0;
  for (var c = 0; c < actualRows; c++) {
    final average = remaining / remainingChunks;
    var length = c == actualRows - 1
        ? remaining
        : math.max(
            1,
            math.min(
              (average * 1.5).ceil(),
              (average + (random() - .5) * average + .5).floor(),
            ),
          );
    length = math.max(1, math.min(length, remaining - (remainingChunks - 1)));
    chunks.add(units.sublist(index, index + length));
    index += length;
    remaining -= length;
    remainingChunks--;
  }
  final rows = <PartitaChunkLayout>[];
  for (var row = 0; row < chunks.length; row++) {
    final chunkUnits = chunks[row],
        words = chunkUnits.expand((u) => u.words).toList();
    if (words.isEmpty) continue;
    final count = words
        .map((w) => w.text.trim())
        .join()
        .replaceAll(RegExp(r'\s+'), '')
        .characters
        .length;
    final left = row.isEven,
        magnitude =
            tuning.staggerMin +
            random() * math.max(tuning.staggerMax - tuning.staggerMin, 0);
    final scale = calm ? 1.0 : .8 + random() * .9;
    final config = PartitaWordConfig(
      '$row-${jsNumberString(words.first.start)}',
      left ? -magnitude : magnitude,
      calm ? 0 : (row - (actualRows - 1) / 2) * 2.5,
      chaotic ? (left ? -3 : 3) : 0,
      (chaotic ? 1 + math.min(count * .01, .05) : 1) * scale,
      chaotic ? '0.4rem' : '0.6rem',
      'center',
      (left ? 1.0 : -1.0) * (chaotic ? 6 : 3),
    );
    rows.add(
      PartitaChunkLayout(
        List.unmodifiable(chunkUnits),
        List.unmodifiable(words),
        List.unmodifiable(displayWordsFromLayoutUnits(chunkUnits)),
        config,
        row,
        row,
      ),
    );
  }
  return PartitaLayout(
    rows.isEmpty
        ? const []
        : [
            PartitaColumn(
              'column-${jsNumberString(line.start)}-0',
              List.unmodifiable(rows),
            ),
          ],
    total,
    chaotic ? 720 : 1000,
  );
}

String partitaLayoutCacheKey(
  LyricLine line,
  String intensity,
  num? fontWeight,
  double windowHeight,
  PartitaTuning tuning,
) => [
  'semantic-layout-v1',
  jsNumberString(line.start),
  jsNumberString(line.end),
  line.words.length,
  line.text,
  wordSegmentationKey(line),
  intensity,
  fontWeight == null ? 'auto' : jsNumberString(fontWeight.toDouble()),
  (windowHeight / 24 + .5).floor(),
  jsNumberString(tuning.staggerMin),
  jsNumberString(tuning.staggerMax),
  tuning.showGuideLines ? 1 : 0,
  tuning.useSemanticLayout ? 1 : 0,
].join('|');

class PartitaLayoutCache {
  final _entries = <String, PartitaLayout>{};
  PartitaLayout getOrBuild(
    LyricLine line,
    String intensity,
    num? fontWeight,
    double windowHeight,
    PartitaTuning tuning, {
    required PlainWordSegmenter segmentPlain,
  }) {
    final key = partitaLayoutCacheKey(
      line,
      intensity,
      fontWeight,
      windowHeight,
      tuning,
    );
    final cached = _entries[key];
    if (cached != null) return cached;
    final value = buildPartitaLayout(
      line,
      intensity,
      windowHeight,
      tuning,
      segmentPlain: segmentPlain,
    );
    if (_entries.length >= 48) _entries.remove(_entries.keys.first);
    _entries[key] = value;
    return value;
  }

  void clear() => _entries.clear();
}
