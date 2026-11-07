import '../wall_types.dart';
import 'explore_lot_data.dart';

// Preserve source Unicode FNV mirrors, stable kind ranking and the table's exact seat identity/order.
enum ExploreEntryKind { album, playlist, mix, artist, song }

class ExploreEntry {
  const ExploreEntry(this.index, this.kind);
  final int index;
  final ExploreEntryKind kind;
  int get rank => switch (kind) {
    ExploreEntryKind.album => 0,
    ExploreEntryKind.playlist || ExploreEntryKind.mix => 1,
    ExploreEntryKind.artist => 2,
    ExploreEntryKind.song => 3,
  };
}

class ExploreSection {
  const ExploreSection(this.key, this.heading, this.entries);
  final String key, heading;
  final List<ExploreEntry> entries;
}

int exploreMirrors(String key, int part) {
  var hash = 0x811c9dc5;
  for (final cp in '$key#$part'.runes) {
    hash = ((hash ^ cp) * 0x01000193) & 0xffffffff;
  }
  hash = ((hash ^ (hash >> 15)) * 0x2c1b3c6d) & 0xffffffff;
  return (hash ^ (hash >> 12)) % 16;
}

class ExploreLotCut {
  ExploreLotCut(this.count, this.mirrors) {
    if (count < 0 || count > 13 || mirrors < 0 || mirrors > 15) {
      throw RangeError('Original lot table range');
    }
  }
  final int count, mirrors;
  int get _offset =>
      exploreLotOffsets[count] + mirrors * 4 * (1 + count + count * count);
  WallBlockSlot _rect(int offset) {
    final b = exploreLotBytes;
    return WallBlockSlot(
      b[offset],
      b[offset + 1],
      b[offset + 2],
      b[offset + 3],
    );
  }

  WallBlockSlot get heading => _rect(_offset);
  List<WallBlockSlot> get seats => _seats(_offset + 4);
  List<WallBlockSlot> _seats(int start) =>
      List.generate(count, (i) => _rect(start + i * 4), growable: false);
  List<WallBlockSlot> grown(int seat) => seat < 0 || seat >= count
      ? seats
      : _seats(_offset + 4 * (1 + count + seat * count));
}

class ExploreLot {
  ExploreLot(this.section, this.part, this.parts, this.tiles, this.cut);
  final int section, part, parts;
  final List<int> tiles;
  final ExploreLotCut cut;
  late final seats = cut.seats;
  late final heading = cut.heading;
  int get mirrors => cut.mirrors;
}

List<ExploreLot> buildExploreStrip(List<ExploreSection> sections) {
  final result = <ExploreLot>[];
  for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
    final section = sections[sectionIndex],
        total = section.entries.length,
        parts = (total / 13).ceil();
    var from = 0;
    for (var part = 0; part < parts; part++) {
      final size = total ~/ parts + (part < total % parts ? 1 : 0);
      final entries = List.generate(
        size,
        (i) => (entry: section.entries[from + i], order: i),
      );
      entries.sort((a, b) {
        final rank = a.entry.rank.compareTo(b.entry.rank);
        return rank == 0 ? a.order.compareTo(b.order) : rank;
      });
      from += size;
      result.add(
        ExploreLot(
          sectionIndex,
          part,
          parts,
          entries.map((v) => v.entry.index).toList(growable: false),
          ExploreLotCut(size, exploreMirrors(section.key, part)),
        ),
      );
    }
  }
  return result;
}

int exploreStride(int count) => count >= 7
    ? 3
    : count >= 4
    ? 2
    : 1;
int exploreLotIndex(int column, int row, int count) =>
    (row + column * exploreStride(count)) % count;
