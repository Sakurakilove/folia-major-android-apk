import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/wall/explore/explore_lots.dart';
import 'package:folia_mobile/library/wall/wall_navigation.dart';
import 'package:folia_mobile/library/wall/wall_types.dart';
import 'package:folia_mobile/library/bravais/bravais_navigation.dart';
import 'package:folia_mobile/library/bravais/shape/bravais_explore_shape.dart';
import 'package:folia_mobile/library/bravais/shape/bravais_wall_shape.dart';
import 'package:folia_mobile/library/bravais/stage/bravais_layout_memory.dart';
import 'package:folia_mobile/library/bravais/stage/bravais_stage_store.dart';

// Existing card case only: original pure focus/layout/session/store observations. No global key routing, persistent Android storage or complete-stage acceptance is implied.
void checkWallNavigation() {
  final data = jsonDecode(
        File('test/fixtures/wall_navigation_reference.json').readAsStringSync(),
      ),
      input = data['shapeInput'],
      shapes = <BravaisWallShape>[
        bravaisBlockShape,
        BravaisExploreShape(
          [
            for (final section in input['sections'])
              ExploreSection(section['key'], section['heading'], [
                for (final entry in section['entries'])
                  ExploreEntry(
                    entry['index'],
                    ExploreEntryKind.values.byName(entry['kind']),
                  ),
              ]),
          ],
          input['origin']['column'],
          input['origin']['row'],
        ),
      ];
  expect(bravaisLayoutStoragePrefix, data['prefix']);
  for (final row in data['moves']) {
    final shape = shapes[row['shape']],
        c = row['column'] as int,
        r = row['row'] as int,
        from = shape.slotAt(c, r, row['seat'])!,
        target = row['target'],
        grown = row['mode'] == 'grown'
            ? shape.grownBlock(c, r, row['seat'])
            : null,
        overrides = {
          for (final slot in grown ?? [])
            slot.key: WallRect(slot.x, slot.y, slot.width, slot.height),
        },
        next = findAdjacentBravaisSlot(
          from,
          WallDirection.values.byName(row['direction']),
          shape: shape,
          drawn: (slot) =>
              overrides[slot.key] ??
              WallRect(slot.x, slot.y, slot.width, slot.height),
          hasContent: (slot) =>
              row['mode'] != 'empty' &&
              shape.headingAt(slot.column, slot.row, slot.slotIndex) == null &&
              (target == null ||
                  slot.column == target['column'] && slot.row == target['row']),
        );
    expect(next?.key, row['result'], reason: '$row');
  }
  for (final row in data['parsed']) {
    expect(
      parseBravaisLayoutRecord(row['raw'])?.toJson(),
      row['result'],
      reason: row['raw'],
    );
  }
  for (final row in data['nearest']) {
    final input = row['input'],
        items = [
          for (final r in input['items'])
            WallRect(
              (r['x'] as num).toDouble(),
              (r['y'] as num).toDouble(),
              (r['width'] as num).toDouble(),
              (r['height'] as num).toDouble(),
            ),
        ],
        nearest = findNearestWallRect(
          items,
          WallPoint(
            (input['point']['x'] as num).toDouble(),
            (input['point']['y'] as num).toDouble(),
          ),
          (r) => r,
        );
    expect(nearest == null ? -1 : items.indexOf(nearest), row['result']);
  }
  for (final row in data['fits']) {
    expect(
      fitBravaisLayoutToShape(
        parseBravaisLayoutRecord(row['raw'])!,
        shapes[row['shape']],
      ).toJson(),
      row['result'],
      reason: '$row',
    );
  }
  final layers = List.generate(4, (_) => Object()),
      store = BravaisStageStore<Object>();
  try {
    for (final row in data['stage']) {
      final input = row['input'], before = store.value;
      BravaisPendingOrigin? taken;
      switch (input['op']) {
        case 'register':
          store.register(
            BravaisLayerSlot.values.byName(input['slot']),
            input['token'],
            layers[input['layer']],
          );
        case 'release':
          store.release(
            BravaisLayerSlot.values.byName(input['slot']),
            input['token'],
          );
        case 'set':
          final p = input['origin'];
          store.setPendingOrigin(
            p == null
                ? null
                : (fromLayerKey: p['fromLayerKey'], slotKey: p['slotKey']),
          );
        case 'take':
          taken = store.takePendingOrigin(input['from']);
      }
      Map<String, Object>? registration(BravaisLayerRegistration<Object>? r) =>
          r == null
          ? null
          : {'token': r.token, 'layer': layers.indexOf(r.layer)};
      Map<String, Object?>? origin(BravaisPendingOrigin? p) => p == null
          ? null
          : {'fromLayerKey': p.fromLayerKey, 'slotKey': p.slotKey};
      expect({
        'home': registration(store.value.home),
        'top': registration(store.value.top),
        'pendingOrigin': origin(store.value.pendingOrigin),
      }, row['state']);
      expect(identical(before, store.value), row['same']);
      expect(origin(taken), row['taken']);
    }
    expect(List.generate(3, (_) => store.takeToken()), data['tokens']);
  } finally {
    store.dispose();
  }
  for (final row in data['current']) {
    final input = row['input'],
        result = resolveCurrentBravaisLayer(
          depth: input['depth'],
          home: input['home'] ? BravaisLayerRegistration(1, layers[0]) : null,
          top: input['top'] ? BravaisLayerRegistration(2, layers[1]) : null,
          previous: input['previous'] == null
              ? null
              : layers[input['previous']],
        );
    expect({
      'owned': result.owned,
      'layer': result.layer == null ? null : layers.indexOf(result.layer!),
    }, row['result']);
  }
  final values = <String, String>{};
  var reads = 0;
  final memory = BravaisLayoutMemory(
    getItem: (key) {
      reads++;
      return values[key];
    },
    setItem: (key, value) => values[key] = value,
  );
  memory.write(
    'home',
    const BravaisLayoutRecord(center: WallPoint(12, 24), startSlotKey: '0,0,0'),
  );
  expect(memory.read('home')!.center!.x, 12);
  values['${bravaisLayoutStoragePrefix}home'] = '{"center":{"x":99,"y":1}}';
  expect(memory.read('home')!.center!.x, 99);
  expect(reads, 2);
}
