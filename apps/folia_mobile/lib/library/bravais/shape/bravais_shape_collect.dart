import '../../wall/seam_plan.dart';
import '../../wall/wall_slots.dart';
import '../../wall/wall_types.dart';
import '../bravais_frame.dart';
import 'bravais_wall_shape.dart';

// Source culling budgets visible seats first, then overscan, but always presents retained keys in fixed world order.
List<WallSlot> collectShapeSlots(
  BravaisWallShape shape,
  WallBounds bounds, {
  int? limit,
  WallBounds? visible,
}) {
  final size = shape.blockSize, result = <WallSlot>[];
  if (limit != null && limit <= 0) return result;
  final regions = visible == null ? [bounds] : [visible, bounds],
      blocks = <String, List<WallSlot>>{};
  List<WallSlot> present() => result
    ..sort((a, b) {
      final row = a.row.compareTo(b.row), col = a.column.compareTo(b.column);
      return row != 0
          ? row
          : col != 0
          ? col
          : a.slotIndex.compareTo(b.slotIndex);
    });
  for (var pass = 0; pass < regions.length; pass++) {
    final region = regions[pass];
    for (
      var row = (region.top / size.height).floor();
      row <= (region.bottom / size.height).floor();
      row++
    ) {
      for (
        var col = (region.left / size.width).floor();
        col <= (region.right / size.width).floor();
        col++
      ) {
        final slots = blocks.putIfAbsent(
          '$col:$row',
          () => shape.blockSlotsAt(col, row),
        );
        for (final slot in slots) {
          if (!slot.bounds.overlaps(region) || !slot.bounds.overlaps(bounds)) {
            continue;
          }
          if (pass == 1 && visible != null && slot.bounds.overlaps(visible)) {
            continue;
          }
          result.add(slot);
          if (limit != null && result.length >= limit) return present();
        }
      }
    }
  }
  return present();
}

double nearestShapeBoundaryX(BravaisWallShape shape, double x) =>
    nearestSeamBoundaryX(x, bravaisMetrics, blockWidth: shape.blockSize.width);
