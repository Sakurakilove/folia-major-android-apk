import '../tiles/bravais_item.dart';
import 'bravais_display.dart';
import 'bravais_wall_data.dart';

// Removal keeps one source display until the erased entries have flipped to empty; data changes must not silently compact ranks before that phase.
enum BravaisDataUpdateKind { refresh, filter, removal, update }

class BravaisDataUpdate {
  const BravaisDataUpdate(this.kind, [this.removed = const {}]);
  final BravaisDataUpdateKind kind;
  final Set<String> removed;
}

Set<String>? detectRemovedEntries(
  List<BravaisItem> before,
  List<BravaisItem> after,
) {
  if (identical(before, after) || before.isEmpty) return null;
  final afterKeys = after.map((i) => i.key).toSet(),
      beforeKeys = before.map((i) => i.key).toSet(),
      removed = before
          .where((i) => !afterKeys.contains(i.key))
          .map((i) => i.key)
          .toSet();
  if (removed.isEmpty || removed.length > 4) return null;
  if (after.where((i) => !beforeKeys.contains(i.key)).length > removed.length) {
    return null;
  }
  final kept = before
          .where((i) => afterKeys.contains(i.key))
          .toList(growable: false),
      keptAfter = after
          .where((i) => beforeKeys.contains(i.key))
          .toList(growable: false);
  if (kept.length != keptAfter.length) return null;
  for (var i = 0; i < kept.length; i++) {
    if (kept[i].key != keptAfter[i].key) return null;
  }
  return removed;
}

BravaisDataUpdate decideDataUpdate(
  BravaisDisplay previous,
  BravaisWallData layer,
) {
  final before = previous.layer;
  if (identical(before.items, layer.items) &&
      before.mode == layer.mode &&
      before.periodCount == layer.periodCount &&
      before.planCount == layer.planCount &&
      before.filterKey == layer.filterKey) {
    return const BravaisDataUpdate(BravaisDataUpdateKind.refresh);
  }
  if (before.mode != layer.mode || before.filterKey != layer.filterKey) {
    return const BravaisDataUpdate(BravaisDataUpdateKind.filter);
  }
  final removed = detectRemovedEntries(before.items, layer.items);
  return removed == null
      ? const BravaisDataUpdate(BravaisDataUpdateKind.update)
      : BravaisDataUpdate(BravaisDataUpdateKind.removal, removed);
}
