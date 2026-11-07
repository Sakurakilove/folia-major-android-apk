import '../../wall/wall_slots.dart';
import '../../wall/wall_types.dart';
import '../bravais_frame.dart';

// All wall consumers ask this shape for seats; explore lots cannot silently fall back to the twelve-card queue template.
abstract class BravaisWallShape {
  const BravaisWallShape();
  String get id;
  bool get explore;
  ({double width, double height}) get blockSize;
  List<WallSlot> blockSlotsAt(int column, int row);
  WallSlot? slotAt(int column, int row, int seat);
  List<WallSlot>? grownBlock(int column, int row, int seat);
  int? entryAt(int column, int row, int seat);
  int? headingAt(int column, int row, int seat);
  WallSlot? nearestEntry(int index, WallPoint near);
  String startKeyAt(WallPoint point);
  String blockKey(int column, int row);
  BravaisShapeStrip? get strip;
}

class BravaisShapeStrip {
  const BravaisShapeStrip(this.column, this.row, this.lots);
  final int column, row;
  final List<String> lots;
}

class BravaisBlockShape extends BravaisWallShape {
  const BravaisBlockShape();
  @override
  String get id => 'blocks';
  @override
  bool get explore => false;
  @override
  ({double width, double height}) get blockSize =>
      wallBlockSize(bravaisMetrics);
  @override
  List<WallSlot> blockSlotsAt(int column, int row) =>
      blockSlots(column, row, bravaisMetrics);
  @override
  WallSlot? slotAt(int column, int row, int seat) =>
      wallSlot(column, row, seat, bravaisMetrics);
  @override
  List<WallSlot>? grownBlock(int column, int row, int seat) =>
      layoutFocusedBlock(column, row, seat, bravaisMetrics);
  @override
  int? entryAt(int column, int row, int seat) => null;
  @override
  int? headingAt(int column, int row, int seat) => null;
  @override
  WallSlot? nearestEntry(int index, WallPoint near) => null;
  @override
  BravaisShapeStrip? get strip => null;
  @override
  String blockKey(int column, int row) => 'blocks';
  @override
  String startKeyAt(WallPoint point) {
    final size = blockSize,
        column = (point.x / size.width).floor(),
        row = (point.y / size.height).floor();
    WallSlot? best;
    var distance = double.infinity;
    for (final slot in blockSlotsAt(column, row)) {
      final dx = slot.centerX - point.x,
          dy = slot.centerY - point.y,
          next = dx * dx + dy * dy;
      if (next < distance) {
        best = slot;
        distance = next;
      }
    }
    return best?.key ?? '$column,$row,0';
  }
}

const bravaisBlockShape = BravaisBlockShape();
