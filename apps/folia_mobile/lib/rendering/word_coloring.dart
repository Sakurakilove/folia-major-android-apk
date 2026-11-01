// Native port of visualizer/wordColoring.ts; matching uses original UTF-16 ranges and priority rules.
abstract interface class WordColorToken {
  String get key;
  bool get timed;
  int get startOffset;
  int get endOffset;
}

class WordColorRange {
  const WordColorRange(
    this.startOffset,
    this.endOffset,
    this.color,
    this.priority,
  );
  final int startOffset, endOffset, priority;
  final String color;
  Map<String, dynamic> toJson() => {
    'startOffset': startOffset,
    'endOffset': endOffset,
    'color': color,
    'priority': priority,
  };
}

class WordColorMatcher {
  const WordColorMatcher(
    this.color,
    this.cjkPhrases,
    this.englishWords,
    this.priority,
  );
  final String color;
  final List<String> cjkPhrases, englishWords;
  final int priority;
  Map<String, dynamic> toJson() => {
    'color': color,
    'cjkPhrases': cjkPhrases,
    'englishWords': englishWords,
    'priority': priority,
  };
}

enum WordColorCjkMatchMode { targetContainsToken, bidirectionalContains, exact }

final _cjk = RegExp(r'[\u4e00-\u9fa5\u3040-\u30ff\uac00-\ud7af]');
final _nonWord = RegExp(r'[^\w]'),
    _word = RegExp(r'\w+'),
    _spaces = RegExp(r'\s+');
String _normalize(String text) => text.toLowerCase().replaceAll(_nonWord, '');
String _entryText(dynamic entry) => entry is Map && entry['word'] is String
    ? (entry['word'] as String).trim()
    : '';
String _entryColor(dynamic entry) =>
    entry is Map && entry['color'] is String ? entry['color'] as String : '';
bool _overlap(int aStart, int aEnd, int bStart, int bEnd) =>
    aStart < bEnd && bStart < aEnd;

List<WordColorMatcher> prepareWordColorMatchers(
  List<dynamic>? entries, {
  bool enabled = true,
}) {
  if (!enabled || entries == null) return const [];
  final result = <WordColorMatcher>[];
  for (final entry in entries) {
    final target = _entryText(entry), color = _entryColor(entry);
    if (target.isEmpty || color.isEmpty) continue;
    if (_cjk.hasMatch(target)) {
      result.add(WordColorMatcher(color, [target], const [], target.length));
    } else {
      final words = target
          .split(_spaces)
          .map(_normalize)
          .where((word) => word.isNotEmpty)
          .toList();
      if (words.isEmpty) continue;
      result.add(
        WordColorMatcher(
          color,
          const [],
          words,
          words.map((w) => w.length).reduce((a, b) => a > b ? a : b),
        ),
      );
    }
  }
  return List.unmodifiable(result);
}

List<WordColorRange> buildWordColorRangesFromMatchers(
  String text,
  List<WordColorMatcher> matchers,
) {
  if (text.isEmpty || matchers.isEmpty) return const [];
  final ranges = <WordColorRange>[],
      english = <String, ({String color, int priority})>{};
  for (final matcher in matchers) {
    for (final target in matcher.cjkPhrases) {
      var cursor = 0;
      while (cursor < text.length) {
        final start = text.indexOf(target, cursor);
        if (start < 0) break;
        ranges.add(
          WordColorRange(
            start,
            start + target.length,
            matcher.color,
            matcher.priority,
          ),
        );
        cursor = start + (target.isEmpty ? 1 : target.length);
      }
    }
    for (final word in matcher.englishWords) {
      final current = english[word];
      if (current == null || matcher.priority > current.priority) {
        english[word] = (color: matcher.color, priority: matcher.priority);
      }
    }
  }
  if (english.isNotEmpty) {
    for (final match in _word.allMatches(text)) {
      final color = english[_normalize(match[0]!)];
      if (color != null) {
        ranges.add(
          WordColorRange(match.start, match.end, color.color, color.priority),
        );
      }
    }
  }
  // Dart List.sort is not stable; retain input order for equal-priority identical ranges as JS sort does.
  final indexed = ranges.indexed.toList()
    ..sort((a, b) {
      final priority = b.$2.priority.compareTo(a.$2.priority);
      if (priority != 0) return priority;
      final start = a.$2.startOffset.compareTo(b.$2.startOffset);
      if (start != 0) return start;
      final end = a.$2.endOffset.compareTo(b.$2.endOffset);
      return end != 0 ? end : a.$1.compareTo(b.$1);
    });
  final selected = <WordColorRange>[];
  for (final (_, range) in indexed) {
    if (!selected.any(
      (current) => _overlap(
        current.startOffset,
        current.endOffset,
        range.startOffset,
        range.endOffset,
      ),
    )) {
      selected.add(range);
    }
  }
  selected.sort(
    (a, b) => a.startOffset != b.startOffset
        ? a.startOffset.compareTo(b.startOffset)
        : a.endOffset.compareTo(b.endOffset),
  );
  return selected;
}

List<WordColorRange> buildWordColorRanges(
  String text,
  List<dynamic>? entries, {
  bool enabled = true,
}) => buildWordColorRangesFromMatchers(
  text,
  prepareWordColorMatchers(entries, enabled: enabled),
);

String resolveWordColor(
  String text,
  List<dynamic>? entries,
  String fallback, {
  bool enabled = true,
  WordColorCjkMatchMode cjkMode = WordColorCjkMatchMode.targetContainsToken,
}) {
  if (!enabled || entries == null || entries.isEmpty) return fallback;
  final clean = text.trim();
  if (clean.isEmpty) return fallback;
  for (final entry in entries) {
    final target = _entryText(entry);
    if (target.isEmpty) continue;
    bool matched;
    if (_cjk.hasMatch(clean)) {
      matched = switch (cjkMode) {
        WordColorCjkMatchMode.exact => target == clean,
        WordColorCjkMatchMode.bidirectionalContains =>
          target.contains(clean) || clean.contains(target),
        WordColorCjkMatchMode.targetContainsToken => target.contains(clean),
      };
    } else {
      final normalized = _normalize(clean);
      matched =
          normalized.isNotEmpty &&
          target
              .split(_spaces)
              .map(_normalize)
              .where((w) => w.isNotEmpty)
              .contains(normalized);
    }
    if (matched) {
      final color = _entryColor(entry);
      return color.isEmpty ? fallback : color;
    }
  }
  return fallback;
}

Map<String, String> resolveTokenColorMap(
  List<WordColorToken> tokens,
  List<WordColorRange> ranges,
) {
  final colors = <String, String>{};
  var index = 0;
  for (final token in tokens) {
    if (!token.timed) continue;
    while (index < ranges.length &&
        ranges[index].endOffset <= token.startOffset) {
      index++;
    }
    if (index < ranges.length &&
        _overlap(
          ranges[index].startOffset,
          ranges[index].endOffset,
          token.startOffset,
          token.endOffset,
        )) {
      colors[token.key] = ranges[index].color;
    }
  }
  return colors;
}
