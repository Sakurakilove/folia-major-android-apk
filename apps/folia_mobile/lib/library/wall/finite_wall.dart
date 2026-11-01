import 'dart:math' as math;

import 'block_reserved_slots.dart';
import 'block_templates.dart';
import 'lattice_layout.dart';
import 'rank_slots.dart';
import 'seam_plan.dart';
import 'wall_slots.dart';
import 'wall_types.dart';
import 'wall_view.dart';

// Finite home layers hold each item once; filtering changes occupied ranks, never the underlying world order.
class FiniteWallInput {
  const FiniteWallInput({
    required this.itemCount,
    required this.metrics,
    required this.view,
    required this.origin,
    this.reservedPerBlock = 0,
    this.startSlotKey,
    this.viewCenter,
  });
  final int itemCount;
  final WallMetrics metrics;
  final WallView view;
  final WallPoint origin;
  final double reservedPerBlock;
  final String? startSlotKey;
  final WallPoint? viewCenter;
}

class FiniteWallBlocks {
  const FiniteWallBlocks(this.columns, this.rows, this.bounds, this.capacity);
  final WallBlockRange columns, rows;
  final WallBounds bounds;
  final int capacity;
  Map<String, Object> toJson() => {
    'columns': columns.toJson(),
    'rows': rows.toJson(),
    'bounds': bounds.toJson(),
    'capacity': capacity,
  };
}

class FiniteWallPlan {
  FiniteWallPlan(this.world, List<WallSlot> order)
    : order = List.unmodifiable(order),
      rankOfSlot = Map.unmodifiable(indexWallRanks(order));
  final FiniteWallBlocks world;
  final List<WallSlot> order;
  final Map<String, int> rankOfSlot;
}

WallBlockRange _centered(double center, int count) {
  final from = (center - count / 2 + .5).floor();
  return WallBlockRange(from, from + count);
}

WallBlockRange _union(WallBlockRange a, WallBlockRange b) =>
    WallBlockRange(math.min(a.from, b.from), math.max(a.to, b.to));
FiniteWallBlocks finiteWallBlocks(FiniteWallInput input) {
  final capacity = blockCapacity(input.reservedPerBlock),
      blocks = math.max(1, (math.max(0, input.itemCount) / capacity).ceil()),
      geometry = latticeGeometry(blocks * wallSlotsPerBlock, input.metrics),
      block = wallBlockSize(input.metrics),
      screen = viewWorldBounds(input.viewCenter ?? input.origin, input.view),
      columns = _union(
        _centered(input.origin.x / block.width, geometry.blocksPerRow),
        WallBlockRange(
          (screen.left / block.width).floor(),
          (screen.right / block.width).floor() + 1,
        ),
      ),
      rows = _union(
        _centered(input.origin.y / block.height, geometry.blockRows),
        WallBlockRange(
          (screen.top / block.height).floor(),
          (screen.bottom / block.height).floor() + 1,
        ),
      );
  return FiniteWallBlocks(
    columns,
    rows,
    WallBounds(
      columns.from * block.width,
      columns.to * block.width - input.metrics.gap,
      rows.from * block.height,
      rows.to * block.height - input.metrics.gap,
    ),
    columns.length * rows.length * capacity,
  );
}

FiniteWallPlan planFiniteWall(FiniteWallInput input) {
  final world = finiteWallBlocks(input);
  return FiniteWallPlan(
    world,
    rankSlots(
      collectBlockRangeSlots(world.columns, world.rows, input.metrics),
      input.origin,
      input.metrics,
      reservedPerBlock: input.reservedPerBlock,
      startSlotKey: input.startSlotKey,
    ),
  );
}

WallBounds? rankedContentBounds(List<WallSlot> order, int count) {
  final used = order.take(math.max(0, count));
  if (used.isEmpty) return null;
  var left = double.infinity,
      right = double.negativeInfinity,
      top = double.infinity,
      bottom = double.negativeInfinity;
  for (final slot in used) {
    left = math.min(left, slot.x);
    right = math.max(right, slot.x + slot.width);
    top = math.min(top, slot.y);
    bottom = math.max(bottom, slot.y + slot.height);
  }
  return WallBounds(left, right, top, bottom);
}

class WallCameraRange {
  const WallCameraRange(
    this.minX,
    this.maxX,
    this.minY,
    this.maxY,
    this.lockedX,
    this.lockedY,
  );
  final double minX, maxX, minY, maxY;
  final bool lockedX, lockedY;
  Map<String, Object> toJson() => {
    'minX': minX,
    'maxX': maxX,
    'minY': minY,
    'maxY': maxY,
    'lockedX': lockedX,
    'lockedY': lockedY,
  };
}

WallCameraRange finiteCameraRange({
  required WallBounds? contentBounds,
  required WallPoint anchor,
  required WallView view,
  required double seamWidth,
  double pad = 60,
}) {
  final content =
          contentBounds ?? WallBounds(anchor.x, anchor.x, anchor.y, anchor.y),
      leftSpan = (view.lineX - seamWidth / 2) / view.scale,
      rightSpan = (view.width - view.lineX - seamWidth / 2) / view.scale,
      halfHeight = view.height / 2 / view.scale;
  var minX = content.left + leftSpan - pad,
      maxX = content.right - rightSpan + pad,
      minY = content.top + halfHeight - pad,
      maxY = content.bottom - halfHeight + pad;
  final lockedX = minX > maxX, lockedY = minY > maxY;
  if (lockedX) {
    minX = anchor.x;
    maxX = anchor.x;
  }
  if (lockedY) {
    minY = anchor.y;
    maxY = anchor.y;
  }
  final seam = seamCameraSpan(
    anchorX: anchor.x,
    openWidth: seamWidth,
    view: view,
  );
  return WallCameraRange(
    math.min(minX, seam.min),
    math.max(maxX, seam.max),
    math.min(minY, anchor.y),
    math.max(maxY, anchor.y),
    lockedX,
    lockedY,
  );
}

WallPoint clampToCameraRange(WallPoint center, WallCameraRange range) =>
    WallPoint(
      math.min(range.maxX, math.max(range.minX, center.x)),
      math.min(range.maxY, math.max(range.minY, center.y)),
    );
double stepCameraAxis(
  double value,
  double delta,
  double min,
  double max, {
  double resistance = .35,
}) {
  final next = value + delta;
  return next < min || next > max ? value + delta * resistance : next;
}
