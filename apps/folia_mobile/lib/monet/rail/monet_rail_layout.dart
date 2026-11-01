import 'dart:math' as math;

import '../../lyrics/lyric_types.dart';
import '../monet_lyrics_model.dart';

// Exact rail geometry from monetRailLayout.ts, separated from glyph rasterization and frame scheduling.
const monetSubtitleTrackStaggerSeconds = .04;
const monetRailMinRows = 7;
const monetScrollIdleResetMs = 1800;
const monetScrollStepPx = 72.0;
const monetTouchStepPx = 52.0;

class MonetLineTone {
  const MonetLineTone(
    this.opacity,
    this.scale,
    this.blur,
    this.baseAlpha,
    this.fontWeight,
    this.zIndex,
  );
  final double opacity, scale, blur, baseAlpha;
  final int fontWeight, zIndex;
}

MonetLineTone resolveMonetRailTone(
  MonetVisibleLineEntry entry,
  double inactiveScale,
  int fontWeight,
) {
  if (entry.status == 'active') {
    return MonetLineTone(1, 1, 0, .34, fontWeight, 4);
  }
  final distance = math.max(entry.offset.abs(), 1),
      waiting = entry.status == 'waiting';
  return MonetLineTone(
    waiting
        ? (.72 - (distance - 1) * .18).clamp(.36, .72)
        : (.52 - (distance - 1) * .12).clamp(.28, .52),
    (inactiveScale * math.pow(.9, distance - 1)).clamp(.68, .92),
    waiting
        ? distance == 1
              ? .7
              : 1.8 + (distance - 2) * .8
        : 1.1 + (distance - 1) * .7,
    waiting ? .46 : .36,
    fontWeight,
    waiting ? 3 - distance : 2 - distance,
  );
}

class PositionedMonetLineEntry {
  PositionedMonetLineEntry(this.entry, this.tone, this.layout)
    : scaledHeight = layout.visualHeightPx * tone.scale;
  final MonetVisibleLineEntry entry;
  final MonetLineTone tone;
  final MonetMeasuredLineLayout layout;
  final double scaledHeight;
  double y = 0;
}

List<MonetVisibleLineEntry> buildScrollableRailEntries(
  List<LyricLine> lines,
  int anchorIndex,
  int activeLineIndex,
) {
  if (lines.isEmpty) return const [];
  final anchor = anchorIndex.clamp(0, lines.length - 1);
  return [
    for (
      var i = math.max(0, anchor - 4);
      i <= math.min(lines.length - 1, anchor + 4);
      i++
    )
      MonetVisibleLineEntry(
        lines[i],
        i,
        i - anchor,
        i == activeLineIndex
            ? 'active'
            : activeLineIndex >= 0 && i < activeLineIndex
            ? 'passed'
            : 'waiting',
      ),
  ];
}

List<PositionedMonetLineEntry> buildPositionedEntries({
  required List<MonetVisibleLineEntry> entries,
  required double railWidth,
  required double railHeight,
  required double lyricFontPx,
  required double inactiveFontPx,
  required double glowBufferPx,
  required MonetLineLayoutInputs inputs,
  required Map<String, MonetMeasuredLineLayout> cache,
  required MonetTextMeasurement measure,
}) {
  final width = railWidth == 0 ? 680.0 : railWidth,
      height = railHeight == 0 ? 340.0 : railHeight;
  final inactiveScale = (inactiveFontPx / math.max(lyricFontPx, 1)).clamp(
    .72,
    .92,
  );
  final contentWidth = math.max(width - glowBufferPx * 2, 0.0);
  final resolved = MonetLineLayoutInputs(
    fontPx: lyricFontPx,
    maxWidthPx: contentWidth - 8,
    translationFontPx: inputs.translationFontPx,
    fontStack: inputs.fontStack,
    translationFontStack: inputs.translationFontStack,
    fontWeight: inputs.fontWeight,
    translationFontWeight: inputs.translationFontWeight,
    secondaryTranslationFontWeight: inputs.secondaryTranslationFontWeight,
    subtitleContentMode: inputs.subtitleContentMode,
  );
  final result = entries.map((entry) {
    final key = buildMonetLayoutCacheKey(entry, resolved);
    final layout = cache.putIfAbsent(
      key,
      () => measureMonetLineLayout(entry.line, entry.status, resolved, measure),
    );
    while (cache.length > 240) {
      cache.remove(cache.keys.first);
    }
    return PositionedMonetLineEntry(
      entry,
      resolveMonetRailTone(entry, inactiveScale, inputs.fontWeight),
      layout,
    );
  }).toList();
  if (result.isEmpty) return result;
  final anchor = math.max(
    0,
    result.indexWhere((entry) => entry.entry.offset == 0),
  );
  result[anchor].y = height * .46 - result[anchor].scaledHeight / 2;
  double gap(PositionedMonetLineEntry a, PositionedMonetLineEntry b) =>
      a.entry.status == 'active' || b.entry.status == 'active'
      ? math.max(18, lyricFontPx * .49)
      : math.max(14, lyricFontPx * .38);
  for (var i = anchor + 1; i < result.length; i++) {
    final previous = result[i - 1], current = result[i];
    current.y = previous.y + previous.scaledHeight + gap(previous, current);
  }
  for (var i = anchor - 1; i >= 0; i--) {
    final current = result[i], next = result[i + 1];
    current.y = next.y - current.scaledHeight - gap(current, next);
  }
  return result;
}
