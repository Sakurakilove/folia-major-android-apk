import '../../wall/block_reserved_slots.dart';
import '../../wall/wall_slots.dart';
import '../bravais_frame.dart';
import '../tiles/bravais_item.dart';

// Source transparency rules are separate from cosmetic card colors: structural windows change rank, start seat and the flip identity.
enum BravaisWallLook { solid, partial, clear }

enum BravaisLayerMode { infinite, finite }

class BravaisWallLookSettings {
  const BravaisWallLookSettings(this.look, this.windowsPerBlock);
  final BravaisWallLook look;
  final double windowsPerBlock;
  int get reserved => look == BravaisWallLook.partial
      ? clampReservedPerBlock(windowsPerBlock)
      : 0;
  BravaisWallLook get next => BravaisWallLook.values[(look.index + 1) % 3];
  double? stepWindows(int delta) {
    if (look != BravaisWallLook.partial) return null;
    final next = windowsPerBlock + delta;
    return next < 1 || next > 6 ? null : next;
  }
}

const solidBravaisWallLook = BravaisWallLookSettings(BravaisWallLook.solid, 0);
BravaisTileKind emptySlotKind(
  BravaisWallLook look,
  bool reserved,
  BravaisLayerMode mode,
) =>
    reserved ||
        (look != BravaisWallLook.solid && mode == BravaisLayerMode.finite)
    ? BravaisTileKind.window
    : BravaisTileKind.wall;
bool seeThroughFace(
  BravaisWallLook look,
  BravaisTileKind kind,
  bool expanded,
) =>
    look == BravaisWallLook.clear &&
    kind == BravaisTileKind.content &&
    !expanded;
bool plateHole(BravaisTileKind kind, bool seeThrough) =>
    kind == BravaisTileKind.window || seeThrough;
bool occludesPlayerFor(BravaisWallLook look, {bool seamClear = false}) =>
    look == BravaisWallLook.solid && !seamClear;
bool opensBackdropFor(BravaisWallLook look, bool seamClear) =>
    look != BravaisWallLook.solid || seamClear;
({bool lyrics, bool blur}) backdropReportFor(
  BravaisWallLook look,
  bool seamClear,
  bool lyrics,
  bool blur,
) {
  final open = opensBackdropFor(look, seamClear);
  return (lyrics: open && lyrics, blur: open && blur);
}

String? resolveStartSlotKey(String? key, int reserved) {
  final address = key == null ? null : parseWallSlotKey(key);
  if (address == null || reserved <= 0) return key;
  final mask = blockReservedMask(
        address.column,
        address.row,
        reserved.toDouble(),
      ),
      i = address.slotIndex;
  if (i < 0 || i >= mask.length || !mask[i]) return key;
  final slots = blockSlots(address.column, address.row, bravaisMetrics),
      origin = slots[i];
  WallSlot? best;
  var distance = double.infinity;
  for (final slot in slots) {
    if (mask[slot.slotIndex]) continue;
    final dx = slot.centerX - origin.centerX,
        dy = slot.centerY - origin.centerY,
        d = dx * dx + dy * dy;
    if (d < distance) {
      distance = d;
      best = slot;
    }
  }
  return best?.key;
}
