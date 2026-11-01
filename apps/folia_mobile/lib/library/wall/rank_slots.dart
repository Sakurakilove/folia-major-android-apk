import 'dart:math' as math;

import 'block_reserved_slots.dart';
import 'wall_slots.dart';
import 'wall_types.dart';

// Strict source rank is stable across filters: content rides its original world seat, never sticky reassignment.
double scoreWallSlot(WallSlot slot, WallPoint origin, WallMetrics metrics) =>
    (slot.centerX - origin.x).abs() +
    (slot.centerY - origin.y).abs() * .9 -
    math.sqrt(slot.area) * metrics.pitch * .35;
List<WallSlot> withoutReservedSlots(Iterable<WallSlot> slots, double count) {
  if (count == 0) return slots.toList();
  final masks = <(int, int), List<bool>>{};
  return [
    for (final slot in slots)
      if (!(masks.putIfAbsent(
        (slot.column, slot.row),
        () => blockReservedMask(slot.column, slot.row, count),
      ))[slot.slotIndex])
        slot,
  ];
}

List<WallSlot> rankSlots(
  Iterable<WallSlot> candidates,
  WallPoint origin,
  WallMetrics metrics, {
  double reservedPerBlock = 0,
  String? startSlotKey,
}) {
  final scored = [
    for (final slot in withoutReservedSlots(candidates, reservedPerBlock))
      (slot: slot, score: scoreWallSlot(slot, origin, metrics)),
  ];
  scored.sort((a, b) {
    var delta = a.score.compareTo(b.score);
    if (delta == 0) delta = a.slot.row.compareTo(b.slot.row);
    if (delta == 0) delta = a.slot.column.compareTo(b.slot.column);
    if (delta == 0) delta = a.slot.slotIndex.compareTo(b.slot.slotIndex);
    return delta;
  });
  final order = scored.map((v) => v.slot).toList();
  final start = startSlotKey == null
      ? -1
      : order.indexWhere((v) => v.key == startSlotKey);
  if (start > 0) order.insert(0, order.removeAt(start));
  return order;
}

Map<String, int> indexWallRanks(List<WallSlot> order) => {
  for (var i = 0; i < order.length; i++) order[i].key: i,
};
