import 'dart:math' as math;

import '../../rendering/js_number.dart';
import '../wall/seam_plan.dart';
import '../wall/wall_slots.dart';
import '../wall/wall_types.dart';
import 'bravais_frame.dart';

// Original solid block backing uses even-odd holes; overlapping moving windows are unioned before drawing so they never fill each other in.
class BravaisPlateBlock {
  const BravaisPlateBlock(this.column, this.row, this.frame, this.holes);
  final int column, row;
  final WallRect frame;
  final Map<String, WallRect> holes;
  String get key => '$column,$row';
}

WallRect bravaisPlateFrame(
  int column,
  int row,
  double? anchorX, {
  double blockWidth = 1632,
  double blockHeight = 1088,
}) {
  final blockX = column * blockWidth;
  bool anchor(int c) =>
      anchorX != null &&
      (seamBoundaryX(c, bravaisMetrics, blockWidth: blockWidth) - anchorX)
              .abs() <
          1e-6;
  final x = anchor(column) ? anchorX! - bravaisMetrics.gap / 2 : blockX - 2,
      right = anchor(column + 1)
          ? anchorX! + bravaisMetrics.gap / 2
          : blockX + blockWidth;
  return WallRect(x, row * blockHeight - 2, right - x, blockHeight + 2);
}

Map<(int, int), ({int column, int row})> mountedWallBlocks(
  Iterable<WallSlot> slots,
) => {
  for (final slot in slots)
    (slot.column, slot.row): (column: slot.column, row: slot.row),
};
List<WallRect> disjointPlateRects(List<WallRect> rects) {
  var overlap = false;
  for (var i = 0; i < rects.length && !overlap; i++) {
    for (var j = i + 1; j < rects.length; j++) {
      if (rects[i].bounds.overlaps(rects[j].bounds)) {
        overlap = true;
        break;
      }
    }
  }
  if (!overlap) return rects;
  final xs = {
        for (final rect in rects) ...[rect.x, rect.x + rect.width],
      }.toList()..sort(),
      ys = {
        for (final rect in rects) ...[rect.y, rect.y + rect.height],
      }.toList()..sort(),
      out = <WallRect>[];
  var open = <(double, double), int>{};
  for (var row = 0; row < ys.length - 1; row++) {
    final y0 = ys[row], y1 = ys[row + 1], next = <(double, double), int>{};
    double? start;
    for (var column = 0; column < xs.length; column++) {
      final inside =
          column < xs.length - 1 &&
          rects.any(
            (r) =>
                r.x <= xs[column] &&
                r.x + r.width >= xs[column + 1] &&
                r.y <= y0 &&
                r.y + r.height >= y1,
          );
      if (inside && start == null) start = xs[column];
      if (!inside && start != null) {
        final end = xs[column],
            key = (start, end),
            aboveIndex = open[key],
            above = aboveIndex == null ? null : out[aboveIndex];
        if (above != null && above.y + above.height == y0) {
          out[aboveIndex!] = WallRect(
            above.x,
            above.y,
            above.width,
            y1 - above.y,
          );
          next[key] = aboveIndex;
        } else {
          next[key] = out.length;
          out.add(WallRect(start, y0, end - start, y1 - y0));
        }
        start = null;
      }
    }
    open = next;
  }
  return out;
}

double roundPlateCoordinate(double v) => (v * 100 + .5).floor() / 100;
String buildBravaisPlatePath(WallRect frame, List<WallRect> holes) {
  String round(double v) => jsNumberString(roundPlateCoordinate(v));
  final output = StringBuffer(
        'M0 0h${round(frame.width)}v${round(frame.height)}h${round(-frame.width)}Z',
      ),
      clipped = <WallRect>[],
      right = frame.x + frame.width,
      bottom = frame.y + frame.height;
  for (final hole in holes) {
    final left = math.max(frame.x, hole.x),
        top = math.max(frame.y, hole.y),
        width = math.min(right, hole.x + hole.width) - left,
        height = math.min(bottom, hole.y + hole.height) - top;
    if (width <= 0 || height <= 0) continue;
    clipped.add(WallRect(left, top, width, height));
  }
  for (final hole in disjointPlateRects(clipped)) {
    output.write(
      'M${round(hole.x - frame.x)} ${round(hole.y - frame.y)}h${round(hole.width)}v${round(hole.height)}h${round(-hole.width)}Z',
    );
  }
  return output.toString();
}
