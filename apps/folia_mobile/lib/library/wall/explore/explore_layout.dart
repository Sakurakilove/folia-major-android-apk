import '../lattice_layout.dart';
import '../wall_types.dart';
import 'explore_lots.dart';

part 'explore_layout_collect.dart';

// The original Lattice/Bravais explore strip and its exact periodic nearest-copy search. This model owns no ticker or UI state.
class ExploreLayout {
  ExploreLayout(List<ExploreSection> input, this.metrics)
    : sections = input
          .where((s) => s.entries.isNotEmpty)
          .toList(growable: false) {
    lots = buildExploreStrip(sections);
    for (var index = 0; index < lots.length; index++) {
      final lot = lots[index];
      for (var seat = 0; seat < lot.tiles.length; seat++) {
        _seatOf[lot.tiles[seat]] = (lot: index, seat: seat);
      }
    }
    _firstLotOf = List.generate(
      sections.length,
      (s) => lots.indexWhere((lot) => lot.section == s),
    );
  }
  final List<ExploreSection> sections;
  final WallMetrics metrics;
  late final List<ExploreLot> lots;
  final _seatOf = <int, ({int lot, int seat})>{};
  late final List<int> _firstLotOf;
  double get pitchX => 12 * metrics.pitch + metrics.cellSize / 2;
  double get pitchY => 8 * metrics.pitch + metrics.cellSize / 2;
  double get lotWidth => 12 * metrics.pitch - metrics.gap;
  double get lotHeight => 8 * metrics.pitch - metrics.gap;
  ExploreLot lotAt(int column, int row) =>
      lots[exploreLotIndex(column, row, lots.length)];
  WallRect rectOf(WallBlockSlot slot, int column, int row) => WallRect(
    column * pitchX + slot.x * metrics.pitch,
    row * pitchY + slot.y * metrics.pitch,
    slot.cols * metrics.pitch - metrics.gap,
    slot.rows * metrics.pitch - metrics.gap,
  );
  WallQueueInstance posterAt(int column, int row, int seat) {
    final lot = lotAt(column, row), rect = rectOf(lot.seats[seat], column, row);
    return WallQueueInstance(
      lot.tiles[seat],
      seat,
      column,
      row,
      rect.x,
      rect.y,
      rect.width,
      rect.height,
    );
  }

  ({int column, int row}) _nearestPlace(
    int index,
    WallPoint offset,
    WallPoint point,
  ) {
    final column = (point.x - offset.x) / pitchX,
        row = (point.y - offset.y) / pitchY,
        middle = (column + .5).floor(),
        reach = (lots.length * pitchY / (2 * pitchX)).ceil() + 1;
    var best = (column: middle, row: 0), bestDistance = double.infinity;
    for (
      var candidate = middle - reach;
      candidate <= middle + reach;
      candidate++
    ) {
      final first =
              (index - candidate * exploreStride(lots.length)) % lots.length,
          candidateRow =
              first + lots.length * ((row - first) / lots.length + .5).floor(),
          dx = (candidate - column) * pitchX,
          dy = (candidateRow - row) * pitchY,
          distance = dx * dx + dy * dy;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = (column: candidate, row: candidateRow);
      }
    }
    return best;
  }

  WallQueueInstance? nearest(int index, WallPoint point) {
    final stands = _seatOf[index];
    if (stands == null) return null;
    final slot = lots[stands.lot].seats[stands.seat],
        offset = WallPoint(
          slot.x * metrics.pitch +
              (slot.cols * metrics.pitch - metrics.gap) / 2,
          slot.y * metrics.pitch +
              (slot.rows * metrics.pitch - metrics.gap) / 2,
        ),
        place = _nearestPlace(stands.lot, offset, point);
    return posterAt(place.column, place.row, stands.seat);
  }

  Map<String, WallRect> grown(WallQueueInstance active) {
    if (lots.isEmpty) return {};
    final lot = lotAt(active.repeatX, active.repeatY);
    if (active.cellSlot < 0 || active.cellSlot >= lot.seats.length) return {};
    final grown = lot.cut.grown(active.cellSlot);
    return {
      for (var seat = 0; seat < grown.length; seat++)
        '$seat:${active.repeatX}:${active.repeatY}': rectOf(
          grown[seat],
          active.repeatX,
          active.repeatY,
        ),
    };
  }

  List<WallQueueInstance> stepCandidates(WallQueueInstance from) => lots.isEmpty
      ? []
      : [
          for (var row = from.repeatY - 1; row <= from.repeatY + 1; row++)
            for (var col = from.repeatX - 1; col <= from.repeatX + 1; col++)
              for (var seat = 0; seat < lotAt(col, row).seats.length; seat++)
                posterAt(col, row, seat),
        ];
  int? sectionAt(WallPoint point) {
    if (lots.isEmpty) return null;
    final column = (point.x / pitchX).floor(), row = (point.y / pitchY).floor();
    if (point.x - column * pitchX > lotWidth ||
        point.y - row * pitchY > lotHeight) {
      return null;
    }
    return lotAt(column, row).section;
  }

  WallPoint? sectionStart(int section, WallPoint point) {
    if (section < 0 ||
        section >= _firstLotOf.length ||
        _firstLotOf[section] < 0) {
      return null;
    }
    final place = _nearestPlace(
      _firstLotOf[section],
      const WallPoint(0, 0),
      point,
    );
    return WallPoint(place.column * pitchX, place.row * pitchY);
  }
}

class ExploreHeading extends WallRect {
  const ExploreHeading(
    this.instanceId,
    this.section,
    this.part,
    this.parts,
    super.x,
    super.y,
    super.width,
    super.height,
  );
  final String instanceId;
  final int section, part, parts;
  Map<String, dynamic> toHeadingJson() => {
    ...super.toJson(),
    'instanceId': instanceId,
    'section': section,
    'part': part,
    'parts': parts,
  };
}
