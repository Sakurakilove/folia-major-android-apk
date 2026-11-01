import 'dart:math' as math;

import 'package:characters/characters.dart';

import 'lyric_types.dart';

// Port of utils/lyrics/graphemeTiming.ts: syllables, punctuation gaps and repeated words keep source timing.
class GraphemeTiming {
  const GraphemeTiming(this.char, this.start, this.end, [this.wordIndex]);
  final String char;
  final double start, end;
  final int? wordIndex;
  Map<String, dynamic> toJson() => {
    'char': char,
    'startTime': start,
    'endTime': end,
    if (wordIndex != null) 'wordIndex': wordIndex,
  };
}

List<GraphemeTiming> _even(
  String text,
  double start,
  double end,
  int? wordIndex,
) {
  final chars = text.characters.toList(growable: false);
  if (chars.isEmpty) return const [];
  final unit = math.max(end - start, 0.0) / chars.length;
  return List.generate(
    chars.length,
    (i) => GraphemeTiming(
      chars[i],
      start + unit * i,
      i == chars.length - 1 ? end : start + unit * (i + 1),
      wordIndex,
    ),
    growable: false,
  );
}

List<GraphemeTiming> buildWordGraphemeTimings(
  LyricWord word, [
  int? wordIndex,
]) => word.syllables.isEmpty
    ? _even(word.text, word.start, word.end, wordIndex)
    : word.syllables
          .expand((s) => _even(s.text, s.start, s.end, wordIndex))
          .toList(growable: false);

int _findSequence(List<String> source, List<String> target, int from) {
  if (target.isEmpty) return from;
  for (var i = from; i <= source.length - target.length; i++) {
    var matched = true;
    for (var j = 0; j < target.length; j++) {
      if (source[i + j] != target[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return i;
  }
  return -1;
}

List<GraphemeTiming> buildLineGraphemeTimeline(LyricLine line) {
  final chars = line.text.characters.toList(growable: false);
  if (chars.isEmpty) return const [];
  if (line.words.isEmpty) return _even(line.text, line.start, line.end, null);
  final timeline = List<GraphemeTiming?>.filled(chars.length, null);
  var cursor = 0;
  var lastTime = line.start;
  for (var w = 0; w < line.words.length; w++) {
    final word = line.words[w],
        wordChars = word.text.characters.toList(growable: false);
    if (wordChars.isEmpty) continue;
    final found = _findSequence(chars, wordChars, cursor);
    final start = found >= 0 ? found : cursor;
    final end = math.min(start + wordChars.length, chars.length);
    for (var gap = cursor; gap < start; gap++) {
      timeline[gap] = GraphemeTiming(chars[gap], word.start, word.start);
    }
    final wordTimings = buildWordGraphemeTimings(word, w);
    for (var local = 0; local < end - start; local++) {
      final fallback = local < wordTimings.length
          ? null
          : _even(wordChars[local], word.start, word.end, w);
      final timing = local < wordTimings.length
          ? wordTimings[local]
          : fallback!.firstOrNull;
      if (timing == null) continue;
      timeline[start + local] = GraphemeTiming(
        chars[start + local],
        timing.start,
        timing.end,
        timing.wordIndex,
      );
      lastTime = math.max(lastTime, timing.end);
    }
    cursor = math.max(cursor, end);
  }
  return List.generate(
    chars.length,
    (i) => timeline[i] ?? GraphemeTiming(chars[i], lastTime, lastTime),
    growable: false,
  );
}
