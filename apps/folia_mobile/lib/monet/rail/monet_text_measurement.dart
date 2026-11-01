import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../lyrics/lyric_types.dart';
import '../monet_lyrics_model.dart';
import '../../rendering/folia_typography.dart';

// Rich inline layout preserves static spans, bidi ordering and atomic timed boxes. Cross-engine shaping is still a parity gate.
class MonetTextRun {
  const MonetTextRun(this.token, this.offset, this.size, this.widthConstraint);
  final MonetDisplayToken token;
  final Offset offset;
  final Size size;
  final double widthConstraint;
}

class MonetTextFlow {
  MonetTextFlow(
    this.tokens,
    this.dimensions,
    this.typography,
    this.fontPx,
    this.width,
    this.runs,
    this.lineCount,
    this.maxLineWidth,
    this.height,
  );
  final List<MonetDisplayToken> tokens;
  final List<PlaceholderDimensions> dimensions;
  final FoliaTypography typography;
  final double fontPx, width;
  final List<MonetTextRun> runs;
  final int lineCount;
  final double maxLineWidth, height;

  TextPainter staticParagraph(TextStyle style) =>
      TextPainter(
          text: TextSpan(
            style: style,
            children: [
              for (final token in tokens)
                if (token.timed)
                  const WidgetSpan(
                    child: SizedBox.shrink(),
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                  )
                else
                  TextSpan(text: token.text),
            ],
          ),
          textDirection: typography.direction,
          locale: typography.locale,
        )
        ..setPlaceholderDimensions(dimensions)
        ..layout(maxWidth: width);
}

class MonetNativeTextMeasurement implements MonetTextMeasurement {
  MonetNativeTextMeasurement(this.resolveTypography);
  final FoliaTypography Function(String fontStack, int weight)
  resolveTypography;
  final _flows = <String, MonetTextFlow>{}, _heights = <String, double>{};

  ({FoliaTypography typography, double px}) _font(String spec) {
    final match = RegExp(r'^(\d+) ([\d.]+)px (.+)$').firstMatch(spec);
    if (match == null) {
      throw FormatException('Invalid original font specification: $spec');
    }
    return (
      typography: resolveTypography(match[3]!, int.parse(match[1]!)),
      px: double.parse(match[2]!),
    );
  }

  TextPainter _paragraph(
    String text,
    FoliaTypography font,
    double px, {
    double width = double.infinity,
  }) => TextPainter(
    text: TextSpan(text: text, style: font.style(px)),
    textDirection: font.direction,
    locale: font.locale,
  )..layout(maxWidth: width);

  void clear() {
    _flows.clear();
    _heights.clear();
  }

  @override
  double lineHeight(String text, String font, double fontPx, double fallback) =>
      _heights.putIfAbsent('$text|$font|$fallback', () {
        final parsed = _font(font),
            paragraph = _paragraph(
              text.isEmpty ? 'Hg' : text,
              parsed.typography,
              parsed.px,
            );
        final paintedHeight = paragraph.computeLineMetrics().fold(
          0.0,
          (value, line) => math.max(value, line.ascent + line.descent),
        );
        paragraph.dispose();
        while (_heights.length >= 420) {
          _heights.remove(_heights.keys.first);
        }
        return math.max(fallback, paintedHeight);
      });

  @override
  int textLineCount(
    String text,
    String font,
    double maxWidth,
    double lineHeight,
  ) {
    final parsed = _font(font),
        paragraph = _paragraph(
          text.isEmpty ? ' ' : text,
          parsed.typography.withHeight(lineHeight / parsed.px),
          parsed.px,
          width: math.max(180, maxWidth),
        );
    final count = math.max(1, paragraph.computeLineMetrics().length);
    paragraph.dispose();
    return count;
  }

  MonetTextFlow flow(
    LyricLine line,
    String font,
    double maxWidth,
    double rowHeight, {
    bool measurement = false,
  }) {
    final parsed = _font(font),
        typography = parsed.typography.withHeight(rowHeight / parsed.px);
    final key =
        '${line.start}|${line.end}|${line.text}|${line.words.map((w) => '${w.start}:${w.end}:${w.text}').join('\u0002')}|$font|$maxWidth|$rowHeight|${typography.cacheKey}|$measurement';
    final cached = _flows[key];
    if (cached != null) return cached;
    final width = measurement
        ? math.max(180.0, maxWidth)
        : math.max(0.0, maxWidth);
    final tokens = buildMonetDisplayTokens(line),
        timed = tokens.where((token) => token.timed).toList();
    final dimensions = <PlaceholderDimensions>[], widths = <double>[];
    for (final token in timed) {
      final paragraph = _paragraph(token.text, typography, parsed.px);
      // CSS inline-block shrink-to-fit: an unbreakable word can overflow; CJK phrases may wrap inside their box.
      final constraint = measurement
          ? paragraph.maxIntrinsicWidth
          : math.min(
              paragraph.maxIntrinsicWidth,
              math.max(paragraph.minIntrinsicWidth, width),
            );
      paragraph.layout(maxWidth: math.max(0, constraint));
      final metrics = paragraph.computeLineMetrics();
      dimensions.add(
        PlaceholderDimensions(
          size: paragraph.size,
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          baselineOffset: metrics.isEmpty ? 0 : metrics.last.baseline,
        ),
      );
      widths.add(math.max(0, constraint));
      paragraph.dispose();
    }
    final prototype = MonetTextFlow(
      tokens,
      dimensions,
      typography,
      parsed.px,
      width,
      const [],
      1,
      0,
      rowHeight,
    );
    final paragraph = prototype.staticParagraph(typography.style(parsed.px));
    final boxes = paragraph.inlinePlaceholderBoxes ?? const <TextBox>[],
        metrics = paragraph.computeLineMetrics();
    final runs = <MonetTextRun>[
      for (var i = 0; i < timed.length && i < boxes.length; i++)
        MonetTextRun(
          timed[i],
          Offset(boxes[i].left, boxes[i].top),
          dimensions[i].size,
          widths[i],
        ),
    ];
    final result = MonetTextFlow(
      tokens,
      dimensions,
      typography,
      parsed.px,
      width,
      List.unmodifiable(runs),
      math.max(1, metrics.length),
      metrics.fold(0.0, (value, line) => math.max(value, line.width)),
      paragraph.height,
    );
    paragraph.dispose();
    while (_flows.length >= 240) {
      _flows.remove(_flows.keys.first);
    }
    return _flows[key] = result;
  }

  @override
  ({int lineCount, double maxLineWidth}) lyricStats(
    LyricLine line,
    String font,
    double maxWidth,
  ) {
    final parsed = _font(font),
        measured = flow(
          line,
          font,
          maxWidth,
          parsed.px * 1.18,
          measurement: true,
        );
    return (lineCount: measured.lineCount, maxLineWidth: measured.maxLineWidth);
  }
}
