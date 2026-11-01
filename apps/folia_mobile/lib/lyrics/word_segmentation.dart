import 'package:characters/characters.dart';

import 'lyric_types.dart';

// Original saved/baked/plain split priority and UTF-16 offsets. The plain engine is supplied by document preparation, never per frame.
class LyricWordSegment {
  const LyricWordSegment(this.segment, this.index, this.isWordLike);
  final String segment;
  final int index;
  final bool isWordLike;
  Map<String, dynamic> toJson() => {
    'segment': segment,
    'index': index,
    'isWordLike': isWordLike,
  };
}

typedef PlainWordSegmenter = List<LyricWordSegment> Function(String text);
final _punctuationOnly = RegExp(r'^[\s\p{P}\p{S}]+$', unicode: true),
    _edgeWhitespace = RegExp(r'^(\s*)(.*?)(\s*)$', unicode: true, dotAll: true);

List<LyricWordSegment> segmentsFromBoundaries(List<String> boundaries) {
  var cursor = 0;
  return [
    for (final segment in boundaries)
      (() {
        final part = LyricWordSegment(
          segment,
          cursor,
          !_punctuationOnly.hasMatch(segment),
        );
        cursor += segment.length;
        return part;
      })(),
  ];
}

bool isValidWordSegmentation(String text, List<String>? boundaries) =>
    boundaries != null && boundaries.isNotEmpty && boundaries.join('') == text;

List<String> _splitEdgeWhitespace(List<String> boundaries) => [
  for (final boundary in boundaries)
    ...(() {
      final match = _edgeWhitespace.firstMatch(boundary), core = match?[2];
      return core?.isNotEmpty == true
          ? [match![1]!, core!, match[3]!].where((s) => s.isNotEmpty)
          : [boundary].where((s) => s.isNotEmpty);
    })(),
];

List<LyricWordSegment> segmentLyricWords(
  LyricLine line,
  PlainWordSegmenter segmentPlain,
) {
  if (isValidWordSegmentation(line.text, line.wordSegments)) {
    return segmentsFromBoundaries(_splitEdgeWhitespace(line.wordSegments!));
  }
  if (isValidWordSegmentation(line.text, line.autoWordSegments)) {
    return segmentsFromBoundaries(line.autoWordSegments!);
  }
  return line.text.isEmpty ? [] : segmentPlain(line.text);
}

// This is used only for the original unavailable-Intl fallback, not as a replacement for a working word segmenter.
List<LyricWordSegment> graphemeWordSegments(String text) =>
    segmentsFromBoundaries(text.characters.toList());
String wordSegmentationKey(LyricLine line) => line.wordSegments != null
    ? line.wordSegments!.map((s) => s.length).join(',')
    : line.autoWordSegments != null
    ? 'a${line.autoWordSegments!.map((s) => s.length).join(',')}'
    : '';
bool hasWordSegmentationOverride(LyricLine line) =>
    isValidWordSegmentation(line.text, line.wordSegments);
