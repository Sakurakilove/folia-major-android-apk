import '../wall/wall_navigation.dart';
import '../wall/wall_slots.dart';
import '../wall/wall_types.dart';
import 'bravais_frame.dart';
import 'shape/bravais_wall_shape.dart';

// Native source focus search sees actual reflow rectangles and shape seats, including finite empty frames. Search the first successful ring, at most three, in original row/column/seat order.
WallSlot? findAdjacentBravaisSlot(
  WallSlot from,
  WallDirection direction, {
  required bool Function(WallSlot) hasContent,
  WallRect Function(WallSlot)? drawn,
  BravaisWallShape shape = bravaisBlockShape,
}) {
  WallRect rect(WallSlot slot) =>
      drawn?.call(slot) ?? WallRect(slot.x, slot.y, slot.width, slot.height);
  final source = rect(from);
  for (var radius = 1; radius <= 3; radius++) {
    final candidates = <({WallSlot value, WallRect rect})>[];
    for (var row = from.row - radius; row <= from.row + radius; row++) {
      for (
        var column = from.column - radius;
        column <= from.column + radius;
        column++
      ) {
        for (final slot in shape.blockSlotsAt(column, row)) {
          if (slot.key == from.key || !hasContent(slot)) continue;
          candidates.add((value: slot, rect: rect(slot)));
        }
      }
    }
    final next = pickAdjacentWallRect(
      source,
      candidates,
      direction,
      bravaisMetrics,
    );
    if (next != null) return next;
  }
  return null;
}
