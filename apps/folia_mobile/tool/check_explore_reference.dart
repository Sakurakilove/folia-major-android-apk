import 'dart:convert';
import 'dart:io';

import 'package:folia_mobile/library/wall/explore/explore_layout.dart';
import 'package:folia_mobile/library/wall/explore/explore_lots.dart';
import 'package:folia_mobile/library/bravais/shape/bravais_explore_shape.dart';
import 'package:folia_mobile/library/bravais/shape/bravais_shape_cache.dart';
import 'package:folia_mobile/library/bravais/shape/bravais_shape_collect.dart';
import 'package:folia_mobile/library/bravais/shape/bravais_wall_shape.dart';
import 'package:folia_mobile/library/wall/wall_slots.dart';

import 'check_wall_reference.dart' as c;

// One fast source contract, not a browser/UI/device acceptance test. The tables themselves are generated directly from the fixed original implementation.
List<ExploreSection> sections(dynamic input) => [
  for (final row in input)
    ExploreSection(row['key'], row['heading'], [
      for (final e in row['entries'])
        ExploreEntry(e['index'], ExploreEntryKind.values.byName(e['kind'])),
    ]),
];
List<Map<String, Object>> slots(List<WallSlot>? values) =>
    values?.map((s) => s.toJson()).toList() ?? [];
void main() {
  final data = jsonDecode(
    File('test/fixtures/explore_reference.json').readAsStringSync(),
  );
  for (final row in data['lotCases']) {
    final count = row['count'] as int,
        mirrors = exploreMirrors(row['key'], row['part']),
        cut = ExploreLotCut(count, mirrors);
    c.equal(mirrors, row['mirrors'], 'mirrors');
    c.equal(cut.heading.toJson(), row['heading'], 'lot.heading');
    c.equal(
      cut.seats.map((v) => v.toJson()).toList(),
      row['seats'],
      'lot.seats',
    );
    c.equal(
      cut.grown(count - 1).map((v) => v.toJson()).toList(),
      row['grown'],
      'lot.grown',
    );
  }
  for (final row in data['cases']) {
    final input = sections(row['sections']),
        layout = ExploreLayout(input, c.metrics(row['metrics'])),
        points = (row['points'] as List).map(c.point).toList(),
        near = layout.near(c.bounds(row['bounds']), 200),
        expected = row['shape'];
    c.equal(
      layout.lots
          .map(
            (l) => {
              'section': l.section,
              'part': l.part,
              'parts': l.parts,
              'tiles': l.tiles,
              'mirrors': l.mirrors,
              'seats': l.seats.map((v) => v.toJson()).toList(),
              'heading': l.heading.toJson(),
            },
          )
          .toList(),
      row['lots'],
      'strip',
    );
    c.equal(
      near.posters.map((v) => v.toJson()).toList(),
      row['near']['posters'],
      'near.posters',
    );
    c.equal(
      near.headings.map((v) => v.toHeadingJson()).toList(),
      row['near']['headings'],
      'near.headings',
    );
    c.equal(
      points.map(layout.sectionAt).toList(),
      row['sectionAt'],
      'section.at',
    );
    c.equal(
      List.generate(
        input.length,
        (i) => layout.sectionStart(i, points[1])?.toJson(),
      ),
      row['sectionStart'],
      'section.start',
    );
    final origin = row['origin'],
        shape = layout.lots.isEmpty
            ? bravaisBlockShape
            : BravaisExploreShape(input, origin['column'], origin['row']);
    c.equal(shape.id, expected['id'], 'shape.id');
    c.equal(
      {'width': shape.blockSize.width, 'height': shape.blockSize.height},
      expected['size'],
      'shape.size',
    );
    final collected = collectShapeSlots(
      shape,
      c.bounds(row['bounds']),
      limit: 73,
      visible: c.bounds(row['visible']),
    );
    c.equal(slots(collected), expected['slots'], 'shape.slots');
    c.equal(
      collected
          .map(
            (s) => {
              'entry': shape.entryAt(s.column, s.row, s.slotIndex),
              'heading': shape.headingAt(s.column, s.row, s.slotIndex),
              'key': shape.blockKey(s.column, s.row),
            },
          )
          .toList(),
      expected['address'],
      'shape.address',
    );
    c.equal(
      collected
          .take(6)
          .map(
            (s) => shape
                .grownBlock(s.column, s.row, s.slotIndex)
                ?.map((s) => s.toJson())
                .toList(),
          )
          .toList(),
      expected['grown'],
      'shape.grown',
    );
    c.equal(
      points.map(shape.startKeyAt).toList(),
      expected['starts'],
      'shape.start',
    );
    final grown = layout.lots.isEmpty
            ? shape
            : BravaisExploreShape(
                [
                  ...input,
                  ...sections([expected['extra']]),
                ],
                origin['column'],
                origin['row'],
              ),
        split = splitGrownSlots(shape, grown, collected);
    c.equal(
      isGrownExploreShape(shape, grown),
      expected['grownPrefix'],
      'shape.prefix',
    );
    c.equal(
      {'kept': slots(split.kept), 'remounted': slots(split.remounted)},
      expected['split'],
      'shape.split',
    );
    for (final n in row['nearest']) {
      final index = n['index'] as int;
      c.equal(
        points.map((p) => layout.nearest(index, p)?.toJson()).toList(),
        n['results'],
        'nearest',
      );
      final expectedNearest = (expected['nearest'] as List).firstWhere(
        (e) => e['index'] == index,
      );
      c.equal(
        points.map((p) => shape.nearestEntry(index, p)?.toJson()).toList(),
        expectedNearest['results'],
        'shape.nearest',
      );
    }
    final active = layout.nearest(0, points[0]);
    c.equal(
      active == null
          ? []
          : layout
                .grown(active)
                .entries
                .map((e) => [e.key, e.value.toJson()])
                .toList(),
      row['grownLayout'],
      'grown.layout',
    );
    c.equal(
      active == null
          ? []
          : layout.stepCandidates(active).map((p) => p.toJson()).toList(),
      row['steps'],
      'steps',
    );
    if (input.any((s) => s.entries.isNotEmpty)) {
      final cached = resolveBravaisShape(input, '-2,3,0');
      if (!identical(cached, resolveBravaisShape(input, '-2,3,9'))) {
        throw StateError('Shape identity changed');
      }
    }
  }
  stdout.writeln(
    'Original explore strip/nearest/cull/focus/shape/Unicode contracts passed (five layouts, five lots).',
  );
}
