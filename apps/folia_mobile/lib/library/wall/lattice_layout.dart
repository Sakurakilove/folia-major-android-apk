import 'dart:math' as math;

import 'block_templates.dart';
import 'wall_types.dart';

// Queue walls repeat their original finite cell; home walls use fixed seats instead. Both share exact block gears.
class LatticeGeometry {
  const LatticeGeometry(
    this.blocksPerRow,
    this.blockRows,
    this.cellSlots,
    this.cellWidth,
    this.cellHeight,
    this.blockWidth,
    this.blockHeight,
  );
  final int blocksPerRow, blockRows, cellSlots;
  final double cellWidth, cellHeight, blockWidth, blockHeight;
  Map<String, Object> toJson() => {
    'blocksPerRow': blocksPerRow,
    'blockRows': blockRows,
    'cellSlots': cellSlots,
    'cellWidth': cellWidth,
    'cellHeight': cellHeight,
    'blockWidth': blockWidth,
    'blockHeight': blockHeight,
  };
}

LatticeGeometry latticeGeometry(int total, WallMetrics metrics) {
  final width = wallBlockCols * metrics.pitch,
      height = wallBlockRows * metrics.pitch,
      blocks = math.max(1, (math.max(0, total) / wallSlotsPerBlock).ceil()),
      columns = blocks <= 1
          ? 1
          : math.max(
              1,
              (math.sqrt(2.2 * blocks * wallBlockRows / wallBlockCols) + .5)
                  .floor(),
            ),
      rows = (blocks / columns).ceil();
  return LatticeGeometry(
    columns,
    rows,
    columns * rows * wallSlotsPerBlock,
    columns * width,
    rows * height,
    width,
    height,
  );
}

class WallQueueInstance {
  const WallQueueInstance(
    this.queueIndex,
    this.cellSlot,
    this.repeatX,
    this.repeatY,
    this.x,
    this.y,
    this.width,
    this.height,
  );
  final int queueIndex, cellSlot, repeatX, repeatY;
  final double x, y, width, height;
  String get instanceId => '$cellSlot:$repeatX:$repeatY';
  WallBounds get bounds => WallBounds(x, x + width, y, y + height);
  Map<String, Object> toJson() => {
    'instanceId': instanceId,
    'queueIndex': queueIndex,
    'cellSlot': cellSlot,
    'repeatX': repeatX,
    'repeatY': repeatY,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

WallQueueInstance _build(
  LatticeGeometry geometry,
  int total,
  int column,
  int row,
  int index,
  WallMetrics metrics,
) {
  final repeatX = (column / geometry.blocksPerRow).floor(),
      repeatY = (row / geometry.blockRows).floor(),
      localColumn = column - repeatX * geometry.blocksPerRow,
      localRow = row - repeatY * geometry.blockRows,
      cellSlot =
          (localRow * geometry.blocksPerRow + localColumn) * wallSlotsPerBlock +
          index,
      slot = blockTemplate(localColumn, localRow)[index],
      pitch = metrics.pitch;
  return WallQueueInstance(
    cellSlot % total,
    cellSlot,
    repeatX,
    repeatY,
    repeatX * geometry.cellWidth +
        localColumn * geometry.blockWidth +
        slot.x * pitch,
    repeatY * geometry.cellHeight +
        localRow * geometry.blockHeight +
        slot.y * pitch,
    slot.cols * pitch - metrics.gap,
    slot.rows * pitch - metrics.gap,
  );
}

({int column, int row, int slotIndex}) instanceBlock(
  LatticeGeometry geometry,
  WallQueueInstance instance,
) {
  final block = instance.cellSlot ~/ wallSlotsPerBlock;
  return (
    column:
        instance.repeatX * geometry.blocksPerRow +
        block % geometry.blocksPerRow,
    row: instance.repeatY * geometry.blockRows + block ~/ geometry.blocksPerRow,
    slotIndex: instance.cellSlot % wallSlotsPerBlock,
  );
}

WallQueueInstance? locateInstanceAt(
  LatticeGeometry geometry,
  int total,
  int column,
  int row,
  int index,
  WallMetrics metrics,
) => total <= 0 || index < 0 || index >= wallSlotsPerBlock
    ? null
    : _build(geometry, total, column, row, index, metrics);
WallQueueInstance? locateNearestInstance(
  LatticeGeometry geometry,
  int total,
  int queueIndex,
  WallPoint point,
  WallMetrics metrics,
) {
  if (total <= 0 || queueIndex < 0 || queueIndex >= total) return null;
  WallQueueInstance? best;
  var bestDistance = double.infinity;
  for (
    var cellSlot = queueIndex;
    cellSlot < geometry.cellSlots;
    cellSlot += total
  ) {
    final block = cellSlot ~/ wallSlotsPerBlock,
        column = block % geometry.blocksPerRow,
        row = block ~/ geometry.blocksPerRow,
        index = cellSlot % wallSlotsPerBlock,
        base = _build(geometry, total, column, row, index, metrics),
        repeatX =
            ((point.x - base.x - base.width / 2) / geometry.cellWidth + .5)
                .floor(),
        repeatY =
            ((point.y - base.y - base.height / 2) / geometry.cellHeight + .5)
                .floor(),
        candidate = _build(
          geometry,
          total,
          repeatX * geometry.blocksPerRow + column,
          repeatY * geometry.blockRows + row,
          index,
          metrics,
        ),
        dx = candidate.x + candidate.width / 2 - point.x,
        dy = candidate.y + candidate.height / 2 - point.y,
        distance = dx * dx + dy * dy;
    if (distance < bestDistance) {
      bestDistance = distance;
      best = candidate;
    }
  }
  return best;
}

List<WallQueueInstance> layoutLattice(
  LatticeGeometry geometry,
  int total,
  WallBounds bounds,
  double overscan,
  WallMetrics metrics,
) {
  if (total <= 0 || geometry.blockWidth <= 0 || geometry.blockHeight <= 0) {
    return [];
  }
  final view = WallBounds(
        bounds.left - overscan,
        bounds.right + overscan,
        bounds.top - overscan,
        bounds.bottom + overscan,
      ),
      result = <WallQueueInstance>[];
  for (
    var row = (view.top / geometry.blockHeight).floor();
    row <= (view.bottom / geometry.blockHeight).floor();
    row++
  ) {
    for (
      var column = (view.left / geometry.blockWidth).floor();
      column <= (view.right / geometry.blockWidth).floor();
      column++
    ) {
      for (var i = 0; i < wallSlotsPerBlock; i++) {
        final instance = _build(geometry, total, column, row, i, metrics);
        if (!instance.bounds.overlaps(view)) continue;
        result.add(instance);
        if (result.length >= 400) return result;
      }
    }
  }
  return result;
}

Map<String, ({double x, double y, double width, double height})>
layoutExpandedBlock(
  LatticeGeometry geometry,
  int total,
  WallQueueInstance active,
  WallMetrics metrics,
) {
  final result =
      <String, ({double x, double y, double width, double height})>{};
  if (total <= 0) return result;
  final block = instanceBlock(geometry, active),
      column = block.column - active.repeatX * geometry.blocksPerRow,
      row = block.row - active.repeatY * geometry.blockRows,
      reflow = blockReflow(column, row, block.slotIndex);
  if (reflow == null) return result;
  final pitch = metrics.pitch,
      originX =
          active.repeatX * geometry.cellWidth + column * geometry.blockWidth,
      originY =
          active.repeatY * geometry.cellHeight + row * geometry.blockHeight,
      blockInCell = row * geometry.blocksPerRow + column;
  for (var i = 0; i < wallSlotsPerBlock; i++) {
    final slot = reflow[i], cellSlot = blockInCell * wallSlotsPerBlock + i;
    result['$cellSlot:${active.repeatX}:${active.repeatY}'] = (
      x: originX + slot.x * pitch,
      y: originY + slot.y * pitch,
      width: slot.cols * pitch - metrics.gap,
      height: slot.rows * pitch - metrics.gap,
    );
  }
  return result;
}

List<WallQueueInstance> locateStepCandidates(
  LatticeGeometry geometry,
  int total,
  WallQueueInstance from,
  WallMetrics metrics,
) {
  final origin = instanceBlock(geometry, from);
  return [
    for (var row = origin.row - 1; row <= origin.row + 1; row++)
      for (
        var column = origin.column - 1;
        column <= origin.column + 1;
        column++
      )
        for (var i = 0; i < wallSlotsPerBlock; i++)
          if (total > 0) _build(geometry, total, column, row, i, metrics),
  ];
}
