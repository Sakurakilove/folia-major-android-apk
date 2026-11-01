import 'dart:math' as math;
import 'dart:ui';

import 'classic_layout.dart';

// CSS flex-wrap's atomic word boxes, per-line justification/alignment and content-center inside the original min-height:300px.
class ClassicFlexLayout {
  const ClassicFlexLayout(this.size, this.slots);
  final Size size;
  final List<Rect> slots;
}

double _margin(String css) => css.endsWith('rem')
    ? double.parse(css.substring(0, css.length - 3)) * 16
    : double.parse(css.replaceFirst('px', ''));
ClassicFlexLayout layoutClassicFlex(
  double width,
  List<Size> sizes,
  ClassicLineLayout layout,
) {
  final rows = <({List<int> indices, double width, double height})>[];
  var indices = <int>[], rowWidth = 0.0, rowHeight = 0.0;
  for (var i = 0; i < sizes.length; i++) {
    final outer = sizes[i].width + _margin(layout.words[i].marginRight);
    if (indices.isNotEmpty && rowWidth + outer > width) {
      rows.add((indices: indices, width: rowWidth, height: rowHeight));
      indices = [];
      rowWidth = rowHeight = 0;
    }
    indices.add(i);
    rowWidth += outer;
    rowHeight = math.max(rowHeight, sizes[i].height);
  }
  if (indices.isNotEmpty) {
    rows.add((indices: indices, width: rowWidth, height: rowHeight));
  }
  final contentHeight = rows.fold(0.0, (h, row) => h + row.height),
      height = math.max(300.0, contentHeight);
  final slots = List<Rect>.filled(sizes.length, Rect.zero);
  var y = (height - contentHeight) / 2;
  for (final row in rows) {
    final free = width - row.width, count = row.indices.length;
    var x = switch (layout.justifyContent) {
      'justify-center' || 'center' => free / 2,
      'justify-end' => free,
      'justify-around' => free < 0 ? free / 2 : free / count / 2,
      _ => 0.0,
    };
    final gap = free <= 0
        ? 0.0
        : layout.justifyContent == 'justify-between' && count > 1
        ? free / (count - 1)
        : layout.justifyContent == 'justify-around'
        ? free / count
        : 0.0;
    for (final i in row.indices) {
      final self = layout.words[i].alignSelf;
      final align = self == 'auto' ? layout.alignItems : self;
      final h = align == null ? row.height : sizes[i].height;
      final dy = switch (align) {
        'items-center' || 'center' => (row.height - h) / 2,
        'items-end' || 'flex-end' => row.height - h,
        _ => 0.0,
      };
      slots[i] = Rect.fromLTWH(x, y + dy, sizes[i].width, h);
      x += sizes[i].width + _margin(layout.words[i].marginRight) + gap;
    }
    y += row.height;
  }
  return ClassicFlexLayout(Size(width, height), List.unmodifiable(slots));
}
