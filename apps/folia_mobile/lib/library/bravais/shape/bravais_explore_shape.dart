import '../../wall/explore/explore_layout.dart';
import '../../wall/explore/explore_lots.dart';
import '../../wall/wall_slots.dart';
import '../../wall/wall_types.dart';
import '../bravais_frame.dart';
import 'bravais_wall_shape.dart';

// Explore is the original hand-drawn lot collage, including its heading seat and exact focus expansion; only the implementation language changes.
class BravaisExploreShape extends BravaisWallShape {
  BravaisExploreShape(List<ExploreSection> sections, this.column, this.row)
    : layout = ExploreLayout(sections, bravaisMetrics) {
    if (layout.lots.isEmpty) {
      throw ArgumentError(
        'Use the source block fallback for an empty explore page',
      );
    }
    id =
        'explore:$column,$row:${layout.lots.map((l) => '${layout.sections[l.section].key}/${l.seats.length}').join('|')}';
    strip = BravaisShapeStrip(
      column,
      row,
      layout.lots
          .map((l) => '${_key(l)}:${l.tiles.join('.')}')
          .toList(growable: false),
    );
  }
  final ExploreLayout layout;
  final int column, row;
  @override
  late final String id;
  @override
  late final BravaisShapeStrip strip;
  @override
  bool get explore => true;
  @override
  ({double width, double height}) get blockSize =>
      (width: layout.pitchX, height: layout.pitchY);
  ExploreLot _lot(int c, int r) => layout.lotAt(c - column, r - row);
  String _key(ExploreLot lot) =>
      '${layout.sections[lot.section].key}/${lot.part}/${lot.seats.length}';
  List<WallBlockSlot> _rects(ExploreLot lot, [List<WallBlockSlot>? seats]) => [
    ...(seats ?? lot.seats),
    lot.heading,
  ];
  WallSlot _slot(int c, int r, int seat, WallBlockSlot rect) {
    final box = layout.rectOf(rect, c, r);
    return WallSlot(
      c,
      r,
      seat,
      box.x,
      box.y,
      box.width,
      box.height,
      rect.cols * rect.rows,
    );
  }

  @override
  List<WallSlot> blockSlotsAt(int column, int row) {
    final rects = _rects(_lot(column, row));
    return List.generate(
      rects.length,
      (i) => _slot(column, row, i, rects[i]),
      growable: false,
    );
  }

  @override
  WallSlot? slotAt(int column, int row, int seat) {
    final rects = _rects(_lot(column, row));
    return seat < 0 || seat >= rects.length
        ? null
        : _slot(column, row, seat, rects[seat]);
  }

  @override
  List<WallSlot>? grownBlock(int column, int row, int seat) {
    final lot = _lot(column, row);
    if (seat < 0 || seat >= lot.seats.length) return null;
    final rects = _rects(lot, lot.cut.grown(seat));
    return List.generate(
      rects.length,
      (i) => _slot(column, row, i, rects[i]),
      growable: false,
    );
  }

  @override
  int? entryAt(int column, int row, int seat) {
    final lot = _lot(column, row);
    return seat < 0 || seat >= lot.tiles.length ? null : lot.tiles[seat];
  }

  @override
  int? headingAt(int column, int row, int seat) {
    final lot = _lot(column, row);
    return seat == lot.seats.length ? lot.section : null;
  }

  @override
  WallSlot? nearestEntry(int index, WallPoint near) {
    final place = layout.nearest(
      index,
      WallPoint(near.x - column * layout.pitchX, near.y - row * layout.pitchY),
    );
    return place == null
        ? null
        : slotAt(place.repeatX + column, place.repeatY + row, place.cellSlot);
  }

  @override
  String startKeyAt(WallPoint point) =>
      '${(point.x / layout.pitchX).floor()},${(point.y / layout.pitchY).floor()},0';
  @override
  String blockKey(int column, int row) => 'explore:${_key(_lot(column, row))}';
}
