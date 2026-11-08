import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/poster/bravais_album_composition.dart';
import 'package:folia_mobile/library/bravais/poster/album/bravais_album_entrance.dart';
import 'package:folia_mobile/library/bravais/poster/album/bravais_album_cover.dart';
import 'package:folia_mobile/library/bravais/poster/album/bravais_album_layout.dart';

// Five fixed-content original CSS layouts extend the existing card case. Rotations/fonts/pixels are explicitly outside these geometric observations.
Future<void> checkWallAlbumLayout(WidgetTester tester) async {
  final reference = jsonDecode(
        File('test/fixtures/album_layout_reference.json').readAsStringSync(),
      ),
      original = resolveBravaisAlbumComposition(reference['seed']),
      composition = BravaisAlbumComposition(
        coverDeg: 0,
        tape: (x: original.tape.x, deg: 0),
        divider: original.divider,
        underline: original.underline,
        hero: original.hero,
        ghostSide: original.ghostSide,
      );
  for (final row in reference['cases']) {
    var now = 0.0;
    final frames = ChangeNotifier(),
        entrance = BravaisAlbumEntrance(
          frames: frames,
          nowMs: () => now,
          words: const [],
        ),
        input = row['input'],
        keys = <String, GlobalKey>{
          for (final id in (row['boxes'] as Map).keys) id: GlobalKey(),
        };
    now = 1200;
    Widget box(String name, {double? width, required double height}) =>
        SizedBox(key: keys[name], width: width, height: height);
    try {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: (input['width'] as num).toDouble(),
              height: (input['height'] as num).toDouble(),
              child: BravaisAlbumLayout(
                entrance: entrance,
                top: box('top', height: (input['top'] as num).toDouble()),
                title: box('title', height: (input['title'] as num).toDouble()),
                scrap: box('scrap', width: 20, height: 100),
                cover: (size) => BravaisAlbumCover(
                  posterSize: size,
                  composition: composition,
                  entrance: entrance,
                  provider: null,
                  anchor: keys['cover'],
                ),
                bottom: [
                  for (var i = 0; i < (input['bottom'] as List).length; i++)
                    box(
                      'bottom$i',
                      height: (input['bottom'][i] as num).toDouble(),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      final cover =
              keys['cover']!.currentContext!.findRenderObject()!
                  as RenderBravaisAlbumCoverBox,
          tape = cover.lastChild!,
          tapePosition = tape.localToGlobal(Offset.zero);
      final actual = <String, Rect>{
        for (final name in keys.keys.where((k) => k != 'stage' && k != 'tape'))
          name: tester.getRect(find.byKey(keys[name]!)),
        'tape': tapePosition & tape.size,
      };
      for (final entry in actual.entries) {
        final expected = row['boxes'][entry.key];
        expect(
          [
            entry.value.left,
            entry.value.top,
            entry.value.width,
            entry.value.height,
          ],
          [expected['x'], expected['y'], expected['width'], expected['height']],
          reason: '$input ${entry.key}',
        );
      }
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      entrance.dispose();
      frames.dispose();
    }
  }
}
