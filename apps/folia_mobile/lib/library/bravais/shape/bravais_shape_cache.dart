import '../../wall/explore/explore_lots.dart';
import '../../wall/wall_slots.dart';
import '../../wall/wall_types.dart';
import 'bravais_explore_shape.dart';
import 'bravais_wall_shape.dart';

// Weak section identity matches the source: refreshing display data alone must not recreate the wall shape or restart its entrance.
final _exploreShapes = Expando<Map<String, BravaisWallShape>>();
BravaisWallShape resolveBravaisShape(
  List<ExploreSection>? sections,
  String? startKey,
) {
  if (sections == null || !sections.any((s) => s.entries.isNotEmpty)) {
    return bravaisBlockShape;
  }
  final address = startKey == null ? null : parseWallSlotKey(startKey),
      column = address?.column ?? 0,
      row = address?.row ?? 0,
      key = '$column,$row',
      cache = _exploreShapes[sections] ??= {};
  return cache[key] ??= BravaisExploreShape(sections, column, row);
}

WallSlot? shapeSlotFromKey(BravaisWallShape shape, String? key) {
  final address = key == null ? null : parseWallSlotKey(key);
  return address == null
      ? null
      : shape.slotAt(address.column, address.row, address.slotIndex);
}

String? exploreStartKey(BravaisWallShape shape, String? key) {
  final address = key == null ? null : parseWallSlotKey(key);
  if (address == null) return key;
  return shape.entryAt(address.column, address.row, address.slotIndex) != null
      ? key
      : '${address.column},${address.row},0';
}

String? moveStartSlotKey(
  String? key,
  BravaisWallShape from,
  BravaisWallShape to,
) {
  if (from.id == to.id) return key;
  final slot = shapeSlotFromKey(from, key);
  return slot == null
      ? null
      : to.startKeyAt(WallPoint(slot.centerX, slot.centerY));
}

({String? key, WallSlot? slot}) resolveShapeShiftStart({
  String? onPrevious,
  String? remembered,
  required BravaisWallShape from,
  List<ExploreSection>? sections,
}) => remembered != null
    ? (
        key: remembered,
        slot: shapeSlotFromKey(
          resolveBravaisShape(sections, remembered),
          remembered,
        ),
      )
    : (
        key: moveStartSlotKey(
          onPrevious,
          from,
          resolveBravaisShape(sections, null),
        ),
        slot: shapeSlotFromKey(from, onPrevious),
      );

bool isGrownExploreShape(BravaisWallShape from, BravaisWallShape to) {
  final a = from.strip, b = to.strip;
  if (a == null ||
      b == null ||
      a.column != b.column ||
      a.row != b.row ||
      b.lots.length <= a.lots.length) {
    return false;
  }
  for (var i = 0; i < a.lots.length; i++) {
    if (a.lots[i] != b.lots[i]) return false;
  }
  return true;
}

({List<WallSlot> kept, List<WallSlot> remounted}) splitGrownSlots(
  BravaisWallShape from,
  BravaisWallShape to,
  List<WallSlot> slots,
) {
  final kept = <WallSlot>[], remounted = <WallSlot>[];
  for (final slot in slots) {
    (from.blockKey(slot.column, slot.row) == to.blockKey(slot.column, slot.row)
            ? kept
            : remounted)
        .add(slot);
  }
  return (kept: kept, remounted: remounted);
}
