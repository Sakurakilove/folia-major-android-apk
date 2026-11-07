import '../../wall/finite_wall.dart';
import '../../wall/wall_slots.dart';
import '../../wall/wall_types.dart';
import '../bravais_frame.dart';

// Filtering keeps the exact finite rank plan until the seam anchor, reserved-window count or required capacity changes.
class BravaisFiniteState {
  const BravaisFiniteState(this.origin, this.plan, this.reservedPerBlock);
  final WallPoint origin;
  final FiniteWallPlan plan;
  final int reservedPerBlock;
  int get capacity => plan.world.capacity;
  List<WallSlot> get order => plan.order;
  Map<String, int> get rankOfSlot => plan.rankOfSlot;
}

BravaisFiniteState planBravaisFinite({
  required int count,
  required double? anchorX,
  required WallPoint center,
  required WallView view,
  int reservedPerBlock = 0,
}) {
  final origin = WallPoint(anchorX ?? center.x, center.y);
  return BravaisFiniteState(
    origin,
    planFiniteWall(
      FiniteWallInput(
        itemCount: count,
        metrics: bravaisMetrics,
        view: view,
        origin: origin,
        viewCenter: center,
        reservedPerBlock: reservedPerBlock.toDouble(),
      ),
    ),
    reservedPerBlock,
  );
}

bool canReuseFinitePlan(
  BravaisFiniteState? previous, {
  required double? anchorX,
  required int count,
  int reservedPerBlock = 0,
}) =>
    previous != null &&
    anchorX != null &&
    previous.origin.x == anchorX &&
    previous.reservedPerBlock == reservedPerBlock &&
    count <= previous.capacity;
WallCameraRange resolveFiniteCameraRange({
  required BravaisFiniteState finite,
  required int itemCount,
  required WallView view,
  required double seamWidth,
}) => finiteCameraRange(
  contentBounds: rankedContentBounds(finite.order, itemCount),
  anchor: finite.origin,
  view: view,
  seamWidth: seamWidth,
);
