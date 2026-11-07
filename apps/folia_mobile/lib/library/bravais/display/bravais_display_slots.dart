import '../../wall/flip_plan.dart';
import '../../wall/wall_slots.dart';
import '../../wall/wall_types.dart';
import '../bravais_wall_wave.dart';
import '../shape/bravais_wall_shape.dart';
import '../tiles/bravais_tile_types.dart';
import 'bravais_display.dart';

// Source planning compares faces, not only item keys: changing windows/transparency is an animated content change too.
List<WallFaceChange> diffDisplays(
  BravaisDisplay? before,
  BravaisDisplay after,
  List<WallSlot> slots,
) => [
  for (final slot in slots)
    WallFaceChange(slot, before?.faceAt(slot).key, after.faceAt(slot).key),
];
Map<String, BravaisFlipStep> toFlipSteps(int token, WallFlipPlan plan) => {
  for (final step in plan.flips)
    step.key: BravaisFlipStep(token, step.to, step.delay, step.direction),
};
Map<String, BravaisFlipStep> toWaveSteps(int token, BravaisWallWavePlan plan) =>
    {
      for (final step in plan.steps)
        step.key: BravaisFlipStep(
          token,
          step.to,
          step.outDelay.toDouble(),
          1,
          waveInDelay: step.inDelay.toDouble(),
        ),
    };
WallSlot? findNearestSlot(
  List<WallSlot> slots,
  WallPoint point, {
  bool Function(WallSlot)? accept,
}) {
  WallSlot? best;
  var distance = double.infinity;
  for (final slot in slots) {
    if (accept != null && !accept(slot)) continue;
    final dx = slot.centerX - point.x,
        dy = slot.centerY - point.y,
        d = dx * dx + dy * dy;
    if (d < distance) {
      distance = d;
      best = slot;
    }
  }
  return best;
}

WallSlot? findItemSlotNear(
  BravaisDisplay? display,
  String itemKey,
  WallPoint point, {
  int radius = 4,
}) {
  if (display == null) return null;
  final size = display.shape.blockSize,
      column = (point.x / size.width).floor(),
      row = (point.y / size.height).floor(),
      candidates = <WallSlot>[];
  for (var y = row - radius; y <= row + radius; y++) {
    for (var x = column - radius; x <= column + radius; x++) {
      for (final slot in display.shape.blockSlotsAt(x, y)) {
        if (display.itemAt(slot)?.key == itemKey) candidates.add(slot);
      }
    }
  }
  return findNearestSlot(candidates, point);
}

Map<String, WallSlot> resolveFocusReflow(
  String? key, {
  BravaisWallShape shape = bravaisBlockShape,
}) {
  final address = key == null ? null : parseWallSlotKey(key);
  if (address == null) return const {};
  final slots = shape.grownBlock(
    address.column,
    address.row,
    address.slotIndex,
  );
  return slots == null ? const {} : {for (final slot in slots) slot.key: slot};
}
