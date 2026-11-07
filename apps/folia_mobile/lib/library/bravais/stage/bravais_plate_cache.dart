import 'package:flutter/foundation.dart';

import '../../wall/wall_slots.dart';
import '../../wall/wall_types.dart';
import '../bravais_plate_geometry.dart';
import '../display/bravais_display.dart';
import '../display/bravais_wall_look.dart';

// Cache only materialized blocks. Camera movement never rebuilds holes; focus reflows remain owned by the shared native reflow snapshot.
class BravaisPlateSet {
  const BravaisPlateSet(this.left, this.right);
  final List<BravaisPlateBlock> left, right;
}

const emptyBravaisPlates = BravaisPlateSet([], []);
typedef _PlateCacheEntry = ({
  BravaisDisplay display,
  String? expanded,
  Map<String, WallRect> reflow,
  double? anchor,
  BravaisPlateBlock block,
  String path,
});

class BravaisPlateCache {
  Map<(int, int), _PlateCacheEntry> _cache = {};
  BravaisPlateSet _plates = emptyBravaisPlates;
  BravaisPlateSet update({
    required bool enabled,
    required List<WallSlot> slots,
    required BravaisDisplay? display,
    required String? expandedSlotKey,
    required Map<String, WallRect> reflow,
    required double? anchorX,
  }) {
    if (!enabled || display == null) {
      _cache.clear();
      return _plates = emptyBravaisPlates;
    }
    final next = <(int, int), _PlateCacheEntry>{},
        left = <BravaisPlateBlock>[],
        right = <BravaisPlateBlock>[],
        size = display.shape.blockSize;
    for (final mounted in mountedWallBlocks(slots).entries) {
      final column = mounted.value.column,
          row = mounted.value.row,
          cached = _cache[mounted.key];
      late _PlateCacheEntry entry;
      if (cached != null &&
          identical(cached.display, display) &&
          cached.expanded == expandedSlotKey &&
          identical(cached.reflow, reflow) &&
          cached.anchor == anchorX) {
        entry = cached;
      } else {
        final holes = <String, WallRect>{};
        for (final slot in display.shape.blockSlotsAt(column, row)) {
          final face = display.faceAt(
            slot,
            expanded: slot.key == expandedSlotKey,
          );
          if (!plateHole(face.kind, face.seeThrough)) continue;
          holes[slot.key] =
              reflow[slot.key] ??
              WallRect(slot.x, slot.y, slot.width, slot.height);
        }
        final frame = bravaisPlateFrame(
              column,
              row,
              anchorX,
              blockWidth: size.width,
              blockHeight: size.height,
            ),
            path = buildBravaisPlatePath(
              frame,
              holes.values.toList(growable: false),
            ),
            block =
                cached != null &&
                    cached.path == path &&
                    cached.block.frame.same(frame)
                ? cached.block
                : BravaisPlateBlock(column, row, frame, holes);
        entry = (
          display: display,
          expanded: expandedSlotKey,
          reflow: reflow,
          anchor: anchorX,
          block: block,
          path: path,
        );
      }
      next[mounted.key] = entry;
      (anchorX != null && column * size.width < anchorX ? left : right).add(
        entry.block,
      );
    }
    _cache = next;
    if (listEquals(left, _plates.left) && listEquals(right, _plates.right)) {
      return _plates;
    }
    return _plates = BravaisPlateSet(left, right);
  }

  void dispose() {
    _cache.clear();
    _plates = emptyBravaisPlates;
  }
}
