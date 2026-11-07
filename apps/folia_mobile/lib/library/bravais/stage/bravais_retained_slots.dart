import '../../wall/wall_slots.dart';

// Source stableWallSlots keeps a retained presentation when a new cull selected exactly the same immutable geometry.
List<WallSlot> stableBravaisSlots(
  List<WallSlot> next,
  List<WallSlot> previous,
) {
  if (next.length != previous.length) return next;
  for (var i = 0; i < next.length; i++) {
    final a = next[i], b = previous[i];
    if (a.column != b.column ||
        a.row != b.row ||
        a.slotIndex != b.slotIndex ||
        a.x != b.x ||
        a.y != b.y ||
        a.width != b.width ||
        a.height != b.height ||
        a.area != b.area ||
        a.centerX != b.centerX ||
        a.centerY != b.centerY) {
      return next;
    }
  }
  return previous;
}
