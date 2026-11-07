import '../../wall/block_reserved_slots.dart';
import '../../wall/start_tile.dart';
import '../../wall/wall_slots.dart';
import '../shape/bravais_shape_cache.dart';
import '../shape/bravais_wall_shape.dart';
import '../tiles/bravais_item.dart';
import '../tiles/bravais_tile_types.dart';
import 'bravais_finite_state.dart';
import 'bravais_wall_data.dart';
import 'bravais_wall_look.dart';

// A display holds the previous source frame during removal/shape exit, independently of the resource that may already have committed new data.
class BravaisDisplay {
  const BravaisDisplay({
    required this.layer,
    required this.shape,
    required this.startSlotKey,
    required this.wrapOffset,
    required this.look,
    required this.reservedPerBlock,
    this.flips = const {},
    this.flipToken = 0,
    this.finite,
    this.hiddenKeys = const {},
    this.entrance,
  });
  factory BravaisDisplay.create(
    BravaisWallData layer,
    String? startKey, {
    BravaisWallLookSettings wallLook = solidBravaisWallLook,
    Map<String, BravaisFlipStep> flips = const {},
    int flipToken = 0,
  }) {
    final shape = resolveBravaisShape(layer.sections, startKey),
        reserved = shape.explore ? 0 : wallLook.reserved,
        start = shape.explore
            ? exploreStartKey(shape, startKey)
            : resolveStartSlotKey(startKey, reserved),
        address = start == null ? null : parseWallSlotKey(start);
    return BravaisDisplay(
      layer: layer,
      shape: shape,
      startSlotKey: start,
      wrapOffset: shape.explore
          ? 0
          : startWallWrapOffset(
              address,
              layer.period,
              reservedPerBlock: reserved.toDouble(),
            ),
      look: wallLook.look,
      reservedPerBlock: reserved,
      flips: flips,
      flipToken: flipToken,
    );
  }
  final BravaisWallData layer;
  final BravaisWallShape shape;
  final String? startSlotKey;
  final int wrapOffset, flipToken, reservedPerBlock;
  final BravaisWallLook look;
  final Map<String, BravaisFlipStep> flips;
  final BravaisFiniteState? finite;
  final Set<String> hiddenKeys;
  final BravaisEntrance? entrance;
  BravaisDisplay withState({
    BravaisWallData? layer,
    Map<String, BravaisFlipStep>? flips,
    int? flipToken,
    BravaisFiniteState? finite,
    Set<String>? hiddenKeys,
    BravaisEntrance? entrance,
    bool clearFinite = false,
    bool clearEntrance = false,
  }) => BravaisDisplay(
    layer: layer ?? this.layer,
    shape: shape,
    startSlotKey: startSlotKey,
    wrapOffset: wrapOffset,
    look: look,
    reservedPerBlock: reservedPerBlock,
    flips: flips ?? this.flips,
    flipToken: flipToken ?? this.flipToken,
    finite: clearFinite ? null : finite ?? this.finite,
    hiddenKeys: hiddenKeys ?? this.hiddenKeys,
    entrance: clearEntrance ? null : entrance ?? this.entrance,
  );
  bool displaysLook(BravaisWallLookSettings settings) =>
      look == settings.look &&
      reservedPerBlock == (shape.explore ? 0 : settings.reserved);
  BravaisItem? itemAt(WallSlot slot) {
    if (layer.items.isEmpty) return null;
    final index = finite != null
        ? finite!.rankOfSlot[slot.key]
        : shape.explore
        ? shape.entryAt(slot.column, slot.row, slot.slotIndex)
        : infiniteWallItem(
            slot.column,
            slot.row,
            slot.slotIndex,
            layer.period,
            wrapOffset,
            reservedPerBlock: reservedPerBlock.toDouble(),
          );
    final item = index == null || index < 0 || index >= layer.items.length
        ? null
        : layer.items[index];
    return item != null && hiddenKeys.contains(item.key) ? null : item;
  }

  BravaisCardFace faceAt(WallSlot slot, {bool expanded = false}) {
    final section = shape.headingAt(slot.column, slot.row, slot.slotIndex);
    if (section != null) {
      final heading = section < 0 || section >= layer.headings.length
          ? null
          : layer.headings[section];
      return BravaisCardFace(
        heading,
        heading == null ? BravaisTileKind.wall : BravaisTileKind.heading,
      );
    }
    final item = itemAt(slot);
    if (item != null) {
      return BravaisCardFace(
        item,
        BravaisTileKind.content,
        seeThrough: seeThroughFace(look, BravaisTileKind.content, expanded),
      );
    }
    final mask = reservedPerBlock == 0
            ? null
            : blockReservedMask(
                slot.column,
                slot.row,
                reservedPerBlock.toDouble(),
              ),
        reserved =
            mask != null &&
            slot.slotIndex >= 0 &&
            slot.slotIndex < mask.length &&
            mask[slot.slotIndex];
    return BravaisCardFace(null, emptySlotKind(look, reserved, layer.mode));
  }
}
