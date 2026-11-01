import 'lyric_types.dart';
import 'active_line_lookup.dart';

export 'lyric_types.dart';

// Normalized lyrics retain all original fields; the provisional raw parser is a separate entry point.

class LyricDocument {
  const LyricDocument(
    this.lines, [
    this.prefixMaxEnd = const [],
    this.source = const {},
    this.lookup,
  ]);
  final List<double> prefixMaxEnd;
  final List<LyricLine> lines;
  final LyricJson source;
  final ActiveLineLookup? lookup;
  String? get title => source['title'] as String?;
  String? get artist => source['artist'] as String?;
  bool? get isWordByWord => source['isWordByWord'] as bool?;
  Map<String, dynamic>? get ttml => source['ttml'] is Map
      ? Map<String, dynamic>.from(source['ttml'] as Map)
      : null;

  factory LyricDocument.fromJson(LyricJson data) => LyricDocument.indexed(
    (data['lines'] as List)
        .map(
          (line) => LyricLine.fromJson(Map<String, dynamic>.from(line as Map)),
        )
        .toList(),
    source: data,
  );

  factory LyricDocument.indexed(
    List<LyricLine> lines, {
    LyricJson source = const {},
  }) {
    var maxEnd = double.negativeInfinity;
    final prefix = lines
        .map((line) {
          final end = line.renderHints?.renderEndTime ?? line.end;
          if (end > maxEnd) maxEnd = end;
          return maxEnd;
        })
        .toList(growable: false);
    return LyricDocument(
      List.unmodifiable(lines),
      List.unmodifiable(prefix),
      Map.unmodifiable(source),
      ActiveLineLookup(lines),
    );
  }

  LyricJson toJson() => {
    ...source,
    'lines': lines.map((line) => line.toJson()).toList(),
  };
  static LyricDocument parse(String source, {double duration = 0}) {
    final yrc = RegExp(r'^\[(\d+),(\d+)\](.*)$');
    final word = RegExp(r'\((\d+),(\d+),[^)]*\)([^()]*)');
    final stamp = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\]');
    final offset = RegExp(
      r'\[offset:([+-]?\d+)\]',
      caseSensitive: false,
    ).firstMatch(source);
    final shift = offset == null ? 0.0 : int.parse(offset[1]!) / 1000;
    final pending = <LyricLine>[];
    for (final raw in source.split(RegExp(r'\r?\n'))) {
      final rich = yrc.firstMatch(raw);
      if (rich != null) {
        final start = int.parse(rich[1]!) / 1000 + shift;
        final end = start + int.parse(rich[2]!) / 1000;
        final words = word
            .allMatches(rich[3]!)
            .map(
              (m) => LyricWord(
                m[3]!,
                int.parse(m[1]!) / 1000 + shift,
                (int.parse(m[1]!) + int.parse(m[2]!)) / 1000 + shift,
              ),
            )
            .toList(growable: false);
        pending.add(
          LyricLine(words.map((w) => w.text).join(), start, end, words),
        );
        continue;
      }
      final stamps = stamp.allMatches(raw).toList();
      if (stamps.isEmpty) continue;
      final text = raw.substring(stamps.last.end);
      for (final m in stamps) {
        pending.add(
          LyricLine(
            text,
            int.parse(m[1]!) * 60 + double.parse(m[2]!) + shift,
            double.nan,
            const [],
          ),
        );
      }
    }
    pending.sort((a, b) => a.start.compareTo(b.start));
    final result = List.generate(pending.length, (i) {
      final line = pending[i];
      final end = line.end.isFinite
          ? line.end
          : i + 1 < pending.length
          ? pending[i + 1].start
          : duration > line.start
          ? duration
          : line.start + 5;
      return LyricLine(
        line.text,
        line.start,
        end,
        line.words.isEmpty
            ? [LyricWord(line.text, line.start, end)]
            : line.words,
      );
    }, growable: false);
    return LyricDocument.indexed(result);
  }

  int latestStartedIndex(double time) {
    var low = 0, high = lines.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].start <= time) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low - 1;
  }

  int activeIndex(double time) {
    if (lines.isEmpty) return -1;
    return (lookup ?? ActiveLineLookup(lines))(time);
  }
}
