import 'dart:math' as math;

import 'block_reserved_slots.dart';
import 'block_templates.dart';
import 'lattice_layout.dart';
import 'wall_types.dart';

// Infinite home content repeats by block period, while the absolute block's reserved seats and clicked origin remain stable.
({int blocksPerRow, int blockRows, int perBlock}) wallWrapPeriod(
  int count, {
  double reservedPerBlock = 0,
}) {
  final perBlock = blockCapacity(reservedPerBlock),
      blocks = math.max(1, (math.max(0, count) / perBlock).ceil()),
      geometry = latticeGeometry(
        blocks * wallSlotsPerBlock,
        const WallMetrics(1, 0),
      );
  return (
    blocksPerRow: geometry.blocksPerRow,
    blockRows: geometry.blockRows,
    perBlock: perBlock,
  );
}

int? wallWrapIndex(
  int column,
  int row,
  int slotIndex,
  int count, {
  double reservedPerBlock = 0,
}) {
  if (count <= 0) return null;
  final mask = blockReservedMask(column, row, reservedPerBlock);
  if (slotIndex >= 0 && slotIndex < mask.length && mask[slotIndex]) return null;
  var within = 0;
  for (var i = 0; i < slotIndex; i++) {
    if (i >= mask.length || !mask[i]) within++;
  }
  final period = wallWrapPeriod(count, reservedPerBlock: reservedPerBlock),
      block =
          (row % period.blockRows) * period.blocksPerRow +
          column % period.blocksPerRow;
  return (block * period.perBlock + within) % count;
}

int startWallWrapOffset(
  ({int column, int row, int slotIndex})? start,
  int count, {
  double reservedPerBlock = 0,
}) {
  if (start == null) return 0;
  final index = wallWrapIndex(
    start.column,
    start.row,
    start.slotIndex,
    count,
    reservedPerBlock: reservedPerBlock,
  );
  return index == null ? 0 : (-index) % count;
}

int? infiniteWallItem(
  int column,
  int row,
  int slotIndex,
  int count,
  int wrapOffset, {
  double reservedPerBlock = 0,
}) {
  final index = wallWrapIndex(
    column,
    row,
    slotIndex,
    count,
    reservedPerBlock: reservedPerBlock,
  );
  return index == null ? null : (index + wrapOffset) % count;
}
