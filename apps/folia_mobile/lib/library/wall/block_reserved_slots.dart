import 'dart:math' as math;

import 'block_templates.dart';

// Separate source hash/mulberry32 stream keeps reserved structural slots independent of template reflection.
int clampReservedPerBlock(double count) =>
    count.isFinite ? math.min(6, math.max(0, (count + .5).floor())) : 0;
int _hash(int column, int row) {
  var value =
      ((column * 0x27d4eb2d) ^ (row * 0x165667b1) ^ 0x5bd1e995) & 0xffffffff;
  value = ((value ^ (value >>> 15)) * 0x85ebca6b) & 0xffffffff;
  value = ((value ^ (value >>> 13)) * 0xc2b2ae35) & 0xffffffff;
  return (value ^ (value >>> 16)) & 0xffffffff;
}

List<int> blockSlotShuffle(int column, int row) {
  final order = List.generate(wallSlotsPerBlock, (i) => i);
  var state = _hash(column, row);
  for (var i = order.length - 1; i > 0; i--) {
    state = (state + 0x6d2b79f5) & 0xffffffff;
    var t = ((state ^ (state >>> 15)) * (1 | state)) & 0xffffffff;
    t = ((t + (((t ^ (t >>> 7)) * (61 | t)) & 0xffffffff)) ^ t) & 0xffffffff;
    final random = ((t ^ (t >>> 14)) & 0xffffffff) / 4294967296;
    final swap = (random * (i + 1)).floor(), old = order[i];
    order[i] = order[swap];
    order[swap] = old;
  }
  return order;
}

List<int> blockReservedSlots(int column, int row, double count) =>
    blockSlotShuffle(
      column,
      row,
    ).take(clampReservedPerBlock(count)).toList(growable: false);
List<bool> blockReservedMask(int column, int row, double count) {
  final mask = List.filled(wallSlotsPerBlock, false);
  for (final index in blockReservedSlots(column, row, count)) {
    mask[index] = true;
  }
  return mask;
}

int blockCapacity(double count) =>
    wallSlotsPerBlock - clampReservedPerBlock(count);
