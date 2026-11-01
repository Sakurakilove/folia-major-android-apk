import 'dart:math' as math;
import 'dart:ui';

import 'partita_prepared_line.dart';

// Original nowrap word row -> padded chunk -> vertically centered column -> row-reverse line; transforms do not feed back into flex sizes.
class PartitaChunkSlot {
  const PartitaChunkSlot(this.rect, this.words);
  final Rect rect;
  final List<Rect> words;
}

class PartitaFlexLayout {
  const PartitaFlexLayout(this.size, this.chunks);
  final Size size;
  final List<List<PartitaChunkSlot>> chunks;
}

PartitaFlexLayout layoutPartitaFlex(double width, PartitaPreparedLine line) {
  final chunkSizes = <List<Size>>[],
      wordSlots = <List<List<Rect>>>[],
      columnWidths = <double>[],
      columnHeights = <double>[];
  double rem(String css) => double.parse(css.replaceAll('rem', '')) * 16;
  for (final column in line.chunks) {
    final sizes = <Size>[], slots = <List<Rect>>[];
    var columnWidth = 0.0, columnHeight = 0.0;
    for (final chunk in column) {
      final glyphs = chunk.words.glyphs;
      final height = glyphs.fold(0.0, (h, g) => math.max(h, g.size.height));
      var x = 8.0;
      final row = <Rect>[];
      for (final glyph in glyphs) {
        row.add(
          Rect.fromLTWH(
            x,
            3.2 + (height - glyph.size.height) / 2,
            glyph.size.width,
            glyph.size.height,
          ),
        );
        x += glyph.size.width + 12.8;
      }
      final size = Size(x + 8, height + 6.4);
      sizes.add(size);
      slots.add(List.unmodifiable(row));
      columnWidth = math.max(columnWidth, size.width);
      columnHeight += size.height + rem(chunk.layout.config.marginBottom);
    }
    chunkSizes.add(sizes);
    wordSlots.add(slots);
    columnWidths.add(math.max(60.8, columnWidth + 24));
    columnHeights.add(columnHeight);
  }
  final gap = rem(line.layout.columnGap),
      height = columnWidths.isEmpty
          ? 320.0
          : math.max(384.0, columnHeights.fold(0.0, math.max));
  final naturalWidth =
      columnWidths.fold(0.0, (a, b) => a + b) +
      gap * math.max(0, columnWidths.length - 1);
  var cursor = (width + naturalWidth) / 2;
  final columns = <List<PartitaChunkSlot>>[];
  for (var c = 0; c < line.chunks.length; c++) {
    final columnWidth = columnWidths[c],
        left = cursor - columnWidth,
        slots = <PartitaChunkSlot>[];
    var y = (height - columnHeights[c]) / 2;
    for (var row = 0; row < line.chunks[c].length; row++) {
      final chunk = line.chunks[c][row], size = chunkSizes[c][row];
      slots.add(
        PartitaChunkSlot(
          Rect.fromLTWH(
            left + (columnWidth - size.width) / 2,
            y,
            size.width,
            size.height,
          ),
          wordSlots[c][row],
        ),
      );
      y += size.height + rem(chunk.layout.config.marginBottom);
    }
    columns.add(List.unmodifiable(slots));
    cursor = left - gap;
  }
  return PartitaFlexLayout(Size(width, height), List.unmodifiable(columns));
}
