import 'lyric_types.dart';
import 'word_segmentation.dart';

part 'semantic_layout_sticky.dart';

// Post-parser layout units retain every source word; grouping for display must never rewrite the normalized lyric document.
class LyricLayoutUnit {
  LyricLayoutUnit({
    required this.text,
    required List<LyricWord> words,
    required this.start,
    required this.end,
    required this.isSemantic,
    this.isSticky,
  }) : words = [...words];
  String text;
  final List<LyricWord> words;
  final double start;
  double end;
  final bool isSemantic;
  bool? isSticky;
  LyricLayoutUnit clone() => LyricLayoutUnit(
    text: text,
    words: words,
    start: start,
    end: end,
    isSemantic: isSemantic,
    isSticky: isSticky,
  );
  Map<String, dynamic> toJson() => {
    'text': text,
    'words': words.map((w) => w.toJson()).toList(),
    'startTime': start,
    'endTime': end,
    'isSemantic': isSemantic,
    if (isSticky != null) 'isSticky': isSticky,
  };
}

final _cjk = RegExp(r'[\u4e00-\u9fa5\u3040-\u30ff\uac00-\ud7af]'),
    _whitespace = RegExp(r'^\s+$', unicode: true);
List<LyricLayoutUnit> singleWordLayoutUnits(List<LyricWord> words) => [
  for (final word in words)
    LyricLayoutUnit(
      text: word.text,
      words: [word],
      start: word.start,
      end: word.end,
      isSemantic: false,
    ),
];

List<LyricLayoutUnit>? _mapSegments(
  List<LyricWordSegment> segments,
  List<LyricWord> words,
) {
  final units = <LyricLayoutUnit>[];
  var wordIndex = 0;
  for (final segment in segments) {
    final text = segment.segment;
    if (text.isEmpty || _whitespace.hasMatch(text)) continue;
    final startIndex = wordIndex;
    var collected = '';
    while (wordIndex < words.length && collected.length < text.length) {
      collected += words[wordIndex++].text;
      if (!text.startsWith(collected)) return null;
    }
    if (collected != text) return null;
    final selected = words.sublist(startIndex, wordIndex);
    if (selected.isEmpty) return null;
    if (!segment.isWordLike && units.isNotEmpty) {
      final previous = units.last;
      previous.text += text;
      previous.words.addAll(selected);
      previous.end = selected.last.end;
      continue;
    }
    units.add(
      LyricLayoutUnit(
        text: text,
        words: selected,
        start: selected.first.start,
        end: selected.last.end,
        isSemantic:
            segment.isWordLike && _cjk.hasMatch(text) && selected.length > 1,
      ),
    );
  }
  return wordIndex != words.length || units.isEmpty ? null : units;
}

List<LyricLayoutUnit> cjkSemanticLayoutUnits(
  LyricLine line,
  PlainWordSegmenter segmentPlain,
) {
  if (line.words.isEmpty) return [];
  final fallback = singleWordLayoutUnits(line.words);
  if (!_cjk.hasMatch(line.text) && !hasWordSegmentationOverride(line)) {
    return fallback;
  }
  final segments = segmentLyricWords(line, segmentPlain);
  return segments.isEmpty
      ? fallback
      : _mapSegments(segments, line.words) ?? fallback;
}

List<LyricLayoutUnit> buildPostLyricLayoutUnits(
  LyricLine line, {
  required PlainWordSegmenter segmentPlain,
  bool semantic = false,
  bool sticky = false,
}) {
  final raw = semantic
      ? cjkSemanticLayoutUnits(line, segmentPlain)
      : singleWordLayoutUnits(line.words);
  return sticky ? applyStickyPunctuationLayoutUnits(raw) : raw;
}

List<LyricWord> displayWordsFromLayoutUnits(List<LyricLayoutUnit> units) => [
  for (final unit in units)
    if (unit.isSticky != true || unit.isSemantic)
      ...unit.words
    else
      LyricWord(unit.text, unit.start, unit.end),
];
