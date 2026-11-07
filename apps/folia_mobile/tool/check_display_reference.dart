import 'dart:convert';
import 'dart:io';

import 'package:folia_mobile/library/bravais/display/bravais_display.dart';
import 'package:folia_mobile/library/bravais/display/bravais_display_update.dart';
import 'package:folia_mobile/library/bravais/display/bravais_finite_state.dart';
import 'package:folia_mobile/library/bravais/display/bravais_wall_data.dart';
import 'package:folia_mobile/library/bravais/display/bravais_wall_look.dart';
import 'package:folia_mobile/library/bravais/shape/bravais_shape_collect.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_item.dart';

import 'check_explore_reference.dart' as e;
import 'check_wall_reference.dart' as c;

// A small pure-source comparison of state projection; final native screen/interaction acceptance is still required.
BravaisItem item(dynamic row) => BravaisItem(
  key: row['key'],
  kind: BravaisItemKind.values.byName(row['kind'] ?? 'track'),
  title: row['title'] ?? '',
  subtitle: row['subtitle'] ?? '',
  badge: row['badge'] ?? '',
);
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/display_reference.json').readAsStringSync(),
  );
  for (final row in fixture['cases']) {
    final data = row['layer'],
        originalItems = (data['items'] as List)
            .map(item)
            .toList(growable: false),
        shape = data['shape'],
        wall = data['wall'];
    BravaisWallData layer(List<BravaisItem> items, {String? filterKey}) =>
        BravaisWallData(
          key: data['key'],
          sessionKey: data['sessionKey'],
          mode: BravaisLayerMode.values.byName(data['mode']),
          items: items,
          periodCount: wall['periodCount'],
          planCount: wall['planCount'],
          filterKey: filterKey ?? wall['filterKey'],
          sections: shape == null ? null : e.sections(shape['sections']),
          headings: shape == null
              ? const []
              : (shape['headings'] as List).map(item).toList(growable: false),
        );
    var display = BravaisDisplay.create(
      layer(originalItems),
      '-1,0,5',
      wallLook: BravaisWallLookSettings(
        BravaisWallLook.values.byName(row['look']),
        3,
      ),
    );
    if (data['mode'] == 'finite') {
      display = display.withState(
        finite: planBravaisFinite(
          count: 23,
          anchorX: -4,
          center: c.point(row['center']),
          view: c.view(row['view']),
          reservedPerBlock: display.reservedPerBlock,
        ),
      );
    }
    final slots = collectShapeSlots(
          display.shape,
          c.bounds(row['bounds']),
          limit: 40,
        ),
        expected = row['display'];
    c.equal(slots.map((s) => s.toJson()).toList(), row['slots'], 'slots');
    c.equal(display.startSlotKey, expected['start'], 'start');
    c.equal(display.wrapOffset, expected['offset'], 'wrap');
    c.equal(display.reservedPerBlock, expected['reserved'], 'reserved');
    List<Map<String, Object?>> faces(BravaisDisplay d) => slots.map((s) {
      final f = d.faceAt(s);
      return {'item': f.item?.key, 'kind': f.kind.name, 'key': f.key};
    }).toList();
    c.equal(faces(display), expected['faces'], 'faces');
    c.equal(
      faces(display.withState(hiddenKeys: {'key-0', 'key-4'})),
      expected['masked'],
      'masked',
    );
    c.equal(
      display.finite == null
          ? null
          : resolveFiniteCameraRange(
              finite: display.finite!,
              itemCount: originalItems.length,
              view: c.view(row['view']),
              seamWidth: 300,
            ).toJson(),
      expected['range'],
      'range',
    );
    final updates = [
      decideDataUpdate(display, layer(originalItems)),
      decideDataUpdate(display, layer(originalItems.sublist(1))),
      decideDataUpdate(display, layer(originalItems, filterKey: 'other')),
    ];
    c.equal(
      updates
          .map(
            (u) => {
              'kind': u.kind.name,
              if (u.kind == BravaisDataUpdateKind.removal)
                'removed': u.removed.toList(),
            },
          )
          .toList(),
      row['updates'],
      'updates',
    );
  }
  for (final row in fixture['removals']) {
    final before = (row['before'] as List)
            .map((k) => item({'key': k}))
            .toList(),
        after = (row['after'] as List).map((k) => item({'key': k})).toList();
    c.equal(
      detectRemovedEntries(before, after)?.toList(),
      row['result'],
      'removal',
    );
  }
  stdout.writeln(
    'Original display/transparency/finite/heading/update/removal contracts passed (twelve projections, four removals).',
  );
}
