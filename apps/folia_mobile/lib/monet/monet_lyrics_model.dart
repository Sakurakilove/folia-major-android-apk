import 'dart:math' as math;

import '../lyrics/grapheme_timing.dart';
import '../lyrics/lyric_types.dart';
import '../lyrics/subtitle_tracks.dart';
import '../rendering/word_coloring.dart';

// Discrete Monet rail model ported from monetLyricsModel.ts; measurement is injected, never run per frame.
String _numberKey(double value) => value == value.truncateToDouble()
    ? value.toInt().toString()
    : value.toString();

class MonetDisplayToken implements WordColorToken {
  const MonetDisplayToken({
    required this.text,
    required this.start,
    required this.end,
    required this.key,
    required this.timed,
    required this.startOffset,
    required this.endOffset,
    required this.graphemeTimings,
  });
  final String text;
  @override
  final String key;
  final double? start, end;
  @override
  final bool timed;
  @override
  final int startOffset;
  @override
  final int endOffset;
  final List<GraphemeTiming> graphemeTimings;
  Map<String, dynamic> toJson() => {
    'text': text,
    'startTime': start,
    'endTime': end,
    'key': key,
    'timed': timed,
    'startOffset': startOffset,
    'endOffset': endOffset,
    'graphemeTimings': graphemeTimings.map((t) => t.toJson()).toList(),
  };
}

List<MonetDisplayToken> buildMonetDisplayTokens(LyricLine line) {
  final stamp = _numberKey(line.start);
  MonetDisplayToken full(String suffix) => MonetDisplayToken(
    text: line.text,
    start: line.start,
    end: line.hints.renderEndTime,
    key: '$stamp-$suffix',
    timed: true,
    startOffset: 0,
    endOffset: line.text.length,
    graphemeTimings: buildLineGraphemeTimeline(line),
  );
  if (line.words.isEmpty) return [full('full')];
  final tokens = <MonetDisplayToken>[];
  var cursor = 0;
  for (var i = 0; i < line.words.length; i++) {
    final word = line.words[i];
    final match = line.text.indexOf(word.text, cursor);
    if (match < 0) continue;
    if (match > cursor) {
      tokens.add(
        MonetDisplayToken(
          text: line.text.substring(cursor, match),
          start: null,
          end: null,
          key: '$stamp-static-$cursor',
          timed: false,
          startOffset: cursor,
          endOffset: match,
          graphemeTimings: const [],
        ),
      );
    }
    final end = match + word.text.length;
    tokens.add(
      MonetDisplayToken(
        text: word.text,
        start: word.start,
        end: word.end,
        key: '$stamp-$i-${_numberKey(word.start)}',
        timed: true,
        startOffset: match,
        endOffset: end,
        graphemeTimings: buildWordGraphemeTimings(word),
      ),
    );
    cursor = end;
  }
  if (cursor < line.text.length) {
    tokens.add(
      MonetDisplayToken(
        text: line.text.substring(cursor),
        start: null,
        end: null,
        key: '$stamp-tail-$cursor',
        timed: false,
        startOffset: cursor,
        endOffset: line.text.length,
        graphemeTimings: const [],
      ),
    );
  }
  return tokens.isNotEmpty ? tokens : [full('fallback-full')];
}

double resolveMonetLargeScreenScale([double width = 1280]) =>
    width <= 1536 ? 1 : 1 + .16 * math.min(1, (width - 1536) / (2200 - 1536));

double resolveClampFontPx(
  double minRem,
  double vw,
  double maxRem,
  double viewportWidth,
) => math.min(maxRem * 16, math.max(minRem * 16, viewportWidth * vw / 100));

double resolveMonetSweepEdgeSoftness(double fontPx) =>
    (fontPx * .45).clamp(6.0, 16.0);
double resolveMonetSweepEnd(double filled, double width, double edge) =>
    width <= 0 ? 0 : filled + edge * (filled / width).clamp(0.0, 1.0);

String resolveMonetLineStatus(
  LyricLine line,
  int index,
  int activeIndex,
  double time,
) {
  if (index == activeIndex ||
      (activeIndex < 0 && time >= line.start && time <= line.end)) {
    return 'active';
  }
  if (time > line.end || (activeIndex >= 0 && index < activeIndex)) {
    return 'passed';
  }
  return 'waiting';
}

String resolveMonetWordStatus(double time, double start, double end) =>
    time < start
    ? 'waiting'
    : time <= end
    ? 'active'
    : 'passed';

class MonetVisibleLineEntry {
  MonetVisibleLineEntry(this.line, this.index, this.offset, this.status)
    : key = '$index-${_numberKey(line.start)}-${line.text}';
  final LyricLine line;
  final int index, offset;
  final String status, key;
  Map<String, dynamic> toJson() => {
    'key': key,
    'index': index,
    'offset': offset,
    'status': status,
  };
}

int _findLine(List<LyricLine> lines, LyricLine? target) {
  if (target == null) return -1;
  final index = lines.indexOf(target);
  return index >= 0
      ? index
      : lines.indexWhere(
          (l) => l.start == target.start && l.text == target.text,
        );
}

({LyricLine? previousLine, LyricLine? activeLine, LyricLine? nextLine})
resolveMonetLyricContext(
  List<LyricLine> lines,
  int currentLineIndex,
  LyricLine? activeLine,
  LyricLine? recentCompletedLine,
  LyricLine? nextLine,
) => activeLine == null
    ? (previousLine: recentCompletedLine, activeLine: null, nextLine: nextLine)
    : (
        previousLine: currentLineIndex > 0 && currentLineIndex <= lines.length
            ? lines[currentLineIndex - 1]
            : null,
        activeLine: activeLine,
        nextLine:
            currentLineIndex + 1 >= 0 && currentLineIndex + 1 < lines.length
            ? lines[currentLineIndex + 1]
            : nextLine,
      );

List<MonetVisibleLineEntry> buildMonetVisibleLineEntries({
  required List<LyricLine> lines,
  required int currentLineIndex,
  required LyricLine? activeLine,
  required LyricLine? recentCompletedLine,
  required LyricLine? upcomingLine,
  required double currentTime,
  int before = 2,
  int after = 2,
}) {
  if (lines.isEmpty) return const [];
  final activeIndex = activeLine == null
      ? -1
      : currentLineIndex >= 0
      ? currentLineIndex
      : _findLine(lines, activeLine);
  final upcoming = _findLine(lines, upcomingLine),
      recent = _findLine(lines, recentCompletedLine);
  final anchor = activeIndex >= 0
      ? activeIndex
      : upcoming >= 0
      ? upcoming
      : recent;
  if (anchor < 0) return const [];
  final start = math.max(0, anchor - before),
      end = math.min(lines.length - 1, anchor + after);
  return [
    for (var i = start; i <= end; i++)
      MonetVisibleLineEntry(
        lines[i],
        i,
        i - anchor,
        resolveMonetLineStatus(lines[i], i, activeIndex, currentTime),
      ),
  ];
}

final _readable = RegExp(r'[\p{L}\p{N}]', unicode: true);
List<SubtitleTrack> resolveMonetSubtitleTracks(
  LyricLine line,
  SubtitleContentMode mode,
) => resolveLyricSubtitleTracks(line, mode, isReadable: _readable.hasMatch);

class MonetLineLayoutInputs {
  const MonetLineLayoutInputs({
    required this.fontPx,
    required this.translationFontPx,
    required this.fontStack,
    required this.translationFontStack,
    required this.maxWidthPx,
    this.fontWeight = 600,
    this.translationFontWeight = 500,
    this.secondaryTranslationFontWeight = 400,
    this.subtitleContentMode = SubtitleContentMode.translation,
  });
  final double fontPx, translationFontPx, maxWidthPx;
  final String fontStack, translationFontStack;
  final int fontWeight, translationFontWeight, secondaryTranslationFontWeight;
  final SubtitleContentMode subtitleContentMode;
}

abstract interface class MonetTextMeasurement {
  double lineHeight(String text, String font, double fontPx, double fallback);
  ({int lineCount, double maxLineWidth}) lyricStats(
    LyricLine line,
    String font,
    double maxWidth,
  );
  int textLineCount(
    String text,
    String font,
    double maxWidth,
    double lineHeight,
  );
}

class MonetSubtitleTrackLayout {
  const MonetSubtitleTrackLayout({
    required this.role,
    required this.text,
    required this.fontPx,
    required this.fontWeight,
    required this.lineCount,
    required this.lineHeightPx,
    required this.contentHeightPx,
    required this.paddingTopPx,
    required this.paddingBottomPx,
    required this.heightPx,
    required this.isClipped,
  });
  final SubtitleTrackRole role;
  final String text;
  final int fontWeight, lineCount;
  final double fontPx,
      lineHeightPx,
      contentHeightPx,
      paddingTopPx,
      paddingBottomPx,
      heightPx;
  final bool isClipped;
  Map<String, dynamic> toJson() => {
    'role': role.name,
    'text': text,
    'fontPx': fontPx,
    'fontWeight': fontWeight,
    'lineCount': lineCount,
    'lineHeightPx': lineHeightPx,
    'contentHeightPx': contentHeightPx,
    'paddingTopPx': paddingTopPx,
    'paddingBottomPx': paddingBottomPx,
    'heightPx': heightPx,
    'isClipped': isClipped,
  };
}

class MonetMeasuredLineLayout {
  const MonetMeasuredLineLayout({
    required this.textLineCount,
    required this.visibleTextLineCount,
    required this.textHeightPx,
    required this.textContentHeightPx,
    required this.textPaddingTopPx,
    required this.textPaddingBottomPx,
    required this.subtitleTracks,
    required this.translationLineCount,
    required this.translationHeightPx,
    required this.translationContentHeightPx,
    required this.translationPaddingTopPx,
    required this.translationPaddingBottomPx,
    required this.visualHeightPx,
    required this.lineHeightPx,
    required this.translationLineHeightPx,
    required this.isTextClipped,
    required this.isTextOverflowingWidth,
    required this.isTranslationClipped,
  });
  final int textLineCount, visibleTextLineCount, translationLineCount;
  final double textHeightPx,
      textContentHeightPx,
      textPaddingTopPx,
      textPaddingBottomPx,
      translationHeightPx,
      translationContentHeightPx,
      translationPaddingTopPx,
      translationPaddingBottomPx,
      visualHeightPx,
      lineHeightPx,
      translationLineHeightPx;
  final List<MonetSubtitleTrackLayout> subtitleTracks;
  final bool isTextClipped, isTextOverflowingWidth, isTranslationClipped;
  Map<String, dynamic> toJson() => {
    'textLineCount': textLineCount,
    'visibleTextLineCount': visibleTextLineCount,
    'textHeightPx': textHeightPx,
    'textContentHeightPx': textContentHeightPx,
    'textPaddingTopPx': textPaddingTopPx,
    'textPaddingBottomPx': textPaddingBottomPx,
    'subtitleTracks': subtitleTracks.map((t) => t.toJson()).toList(),
    'translationLineCount': translationLineCount,
    'translationHeightPx': translationHeightPx,
    'translationContentHeightPx': translationContentHeightPx,
    'translationPaddingTopPx': translationPaddingTopPx,
    'translationPaddingBottomPx': translationPaddingBottomPx,
    'visualHeightPx': visualHeightPx,
    'lineHeightPx': lineHeightPx,
    'translationLineHeightPx': translationLineHeightPx,
    'isTextClipped': isTextClipped,
    'isTextOverflowingWidth': isTextOverflowingWidth,
    'isTranslationClipped': isTranslationClipped,
  };
}

String _font(int weight, double px, String stack) =>
    '$weight ${_numberKey(px)}px $stack';

MonetSubtitleTrackLayout _measureSubtitle(
  SubtitleTrack track,
  bool secondary,
  MonetLineLayoutInputs inputs,
  MonetTextMeasurement measure,
) {
  final px =
      inputs.translationFontPx * (secondary ? secondaryTrackSizeFactor : 1);
  final weight = secondary
      ? inputs.secondaryTranslationFontWeight
      : inputs.translationFontWeight;
  final font = _font(weight, px, inputs.translationFontStack);
  final lineHeight = measure.lineHeight(track.text, font, px, px * 1.28);
  final top = secondary ? px * secondaryTrackGapEm : math.max(px * .45, 7.0);
  final bottom = math.max(px * .18, 5.0);
  final raw = measure.textLineCount(
    track.text,
    font,
    math.max(inputs.maxWidthPx, 180),
    lineHeight,
  );
  final count = math.min(raw, 2), content = count * lineHeight;
  return MonetSubtitleTrackLayout(
    role: track.role,
    text: track.text,
    fontPx: px,
    fontWeight: weight,
    lineCount: count,
    lineHeightPx: lineHeight,
    contentHeightPx: content,
    paddingTopPx: top,
    paddingBottomPx: bottom,
    heightPx: content + top + bottom,
    isClipped: raw > count,
  );
}

MonetMeasuredLineLayout measureMonetLineLayout(
  LyricLine line,
  String status,
  MonetLineLayoutInputs inputs,
  MonetTextMeasurement measure,
) {
  final px = inputs.fontPx, subPx = inputs.translationFontPx;
  final font = _font(inputs.fontWeight, px, inputs.fontStack);
  final height = measure.lineHeight(line.text, font, px, px * 1.18);
  final top = math.max(px * .16, 8.0), bottom = math.max(px * .34, 14.0);
  final stats = measure.lyricStats(
    line,
    font,
    math.max(inputs.maxWidthPx, 180),
  );
  final count = math.max(stats.lineCount, 1),
      visible = math.min(count, status == 'active' ? 14 : 2);
  final content = visible * height, textHeight = content + top + bottom;
  final tracks = status == 'active'
      ? resolveMonetSubtitleTracks(line, inputs.subtitleContentMode)
      : <SubtitleTrack>[];
  final layouts = [
    for (var i = 0; i < tracks.length; i++)
      _measureSubtitle(tracks[i], i > 0, inputs, measure),
  ];
  final total = layouts.fold(0.0, (sum, t) => sum + t.heightPx);
  return MonetMeasuredLineLayout(
    textLineCount: count,
    visibleTextLineCount: visible,
    textHeightPx: textHeight,
    textContentHeightPx: content,
    textPaddingTopPx: top,
    textPaddingBottomPx: bottom,
    subtitleTracks: List.unmodifiable(layouts),
    translationLineCount: layouts.fold(0, (sum, t) => sum + t.lineCount),
    translationHeightPx: total,
    translationContentHeightPx: layouts.fold(
      0.0,
      (sum, t) => sum + t.contentHeightPx,
    ),
    translationPaddingTopPx: layouts.isEmpty
        ? math.max(subPx * .45, 7.0)
        : layouts.first.paddingTopPx,
    translationPaddingBottomPx: layouts.isEmpty
        ? math.max(subPx * .18, 5.0)
        : layouts.last.paddingBottomPx,
    visualHeightPx: textHeight + total,
    lineHeightPx: height,
    translationLineHeightPx: layouts.isEmpty
        ? measure.lineHeight(
            '',
            _font(
              inputs.translationFontWeight,
              subPx,
              inputs.translationFontStack,
            ),
            subPx,
            subPx * 1.28,
          )
        : layouts.first.lineHeightPx,
    isTextClipped: count > visible,
    isTextOverflowingWidth: stats.maxLineWidth > inputs.maxWidthPx,
    isTranslationClipped: layouts.any((t) => t.isClipped),
  );
}

String buildMonetLayoutCacheKey(
  MonetVisibleLineEntry entry,
  MonetLineLayoutInputs inputs,
) => [
  entry.index,
  _numberKey(entry.line.start),
  _numberKey(entry.line.end),
  entry.line.text,
  inputs.subtitleContentMode.name,
  entry.status == 'active'
      ? resolveMonetSubtitleTracks(
          entry.line,
          inputs.subtitleContentMode,
        ).map((t) => '${t.role.name}:${t.text}').join('\u0002')
      : '',
  entry.status,
  _numberKey(inputs.fontPx),
  _numberKey(inputs.translationFontPx),
  inputs.fontStack,
  inputs.translationFontStack,
  inputs.fontWeight,
  inputs.translationFontWeight,
  inputs.secondaryTranslationFontWeight,
  _numberKey(inputs.maxWidthPx),
].join('\u0001');
