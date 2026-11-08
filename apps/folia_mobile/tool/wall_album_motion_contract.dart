import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/rendering/css_numeric.dart';
import 'package:folia_mobile/library/bravais/poster/album/bravais_album_entrance.dart';
import 'package:folia_mobile/library/bravais/poster/album/bravais_album_motion.dart';
import 'package:folia_mobile/library/bravais/poster/album/bravais_album_cover.dart';
import 'package:folia_mobile/library/bravais/poster/bravais_album_composition.dart';
import 'package:folia_mobile/library/bravais/cover/bravais_cover_quad.dart';

// Extend the existing card case with source CSS individual-property observations and one retained native transform. Computed-style precision is diagnostic, not final pixel acceptance.
Future<void> checkWallAlbumMotion(WidgetTester tester) async {
  final reference = jsonDecode(
    File('test/fixtures/album_motion_reference.json').readAsStringSync(),
  );
  for (final row in reference['cases']) {
    var now = 0.0;
    final clock = _AlbumFrames(),
        reduced = row['variant'] == 'reduced',
        cover = switch (row['variant']) {
          'pending' => BravaisAlbumCoverState.pending,
          'landed' => BravaisAlbumCoverState.landed,
          _ => BravaisAlbumCoverState.ordinary,
        },
        entrance = BravaisAlbumEntrance(
          frames: clock,
          nowMs: () => now,
          words: const ['A', 'B', 'C', ' '],
          reducedMotion: reduced,
          cover: cover,
        );
    void consumer() {}
    entrance.addListener(consumer);
    try {
      for (final state in row['states']) {
        now = (state['at'] as num).toDouble();
        clock.tick();
        for (final expected in state['parts']) {
          final id = expected['id'] as String,
              index = id.startsWith('word')
                  ? int.parse(id.substring(4))
                  : id.startsWith('bottom')
                  ? int.parse(id.substring(6))
                  : 0,
              part = BravaisAlbumPart.values.byName(
                id.startsWith('word')
                    ? 'word'
                    : id.startsWith('bottom')
                    ? 'bottom'
                    : id,
              ),
              value = entrance.sample(part, index),
              em = part == BravaisAlbumPart.word
                  ? (expected['em'] as num).toDouble()
                  : 1.0;
          // CSS computed-style serialization exposes six significant digits;
          // compare that exact representation after the native float32 fields.
          void number(double actual, String key) => expect(
            double.parse(actual.toStringAsPrecision(6)),
            (expected[key] as num).toDouble(),
            reason: '${row['variant']}:$now:$id.$key',
          );
          number(value.opacity, 'opacity');
          number(cssFloat32(value.x * em), 'x');
          number(cssFloat32(value.y * em), 'y');
          number(value.rotate, 'rotate');
          number(value.scaleX, 'scaleX');
          number(value.scaleY, 'scaleY');
          // Tape inherits its cover's visibility; its own animation still runs.
          expect(
            value.visible &&
                !(part == BravaisAlbumPart.tape &&
                    cover == BravaisAlbumCoverState.pending),
            expected['visible'],
          );
        }
      }
      expect(clock.count, 0);
    } finally {
      entrance.removeListener(consumer);
      entrance.dispose();
      clock.dispose();
    }
  }
  await _retainedAlbumLayer(tester);
}

Future<void> _retainedAlbumLayer(WidgetTester tester) async {
  var now = 0.0;
  final clock = _AlbumFrames(),
      entrance = BravaisAlbumEntrance(
        frames: clock,
        nowMs: () => now,
        words: const ['A', ' ', 'B'],
      ),
      key = GlobalKey(),
      composition = resolveBravaisAlbumComposition('album:source');
  var builds = 0;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Builder(
          builder: (_) {
            builds++;
            return BravaisAlbumCover(
              posterSize: const Size(400, 600),
              composition: composition,
              entrance: entrance,
              provider: null,
              anchor: key,
            );
          },
        ),
      ),
    ),
  );
  final retained = key.currentContext!.findRenderObject();
  for (final at in [120.0, 320.0, 560.0, 680.0, 880.0, 1000.0, 1120.0]) {
    now = at;
    clock.tick();
    await tester.pump();
    expect(identical(key.currentContext!.findRenderObject(), retained), true);
    expect(builds, 1);
    final box = retained! as RenderBox,
        quad = measureBravaisCover(box)!,
        cover = entrance.sample(BravaisAlbumPart.cover);
    expect(box.size, const Size.square(198));
    final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(quad.center.dx, closeTo(viewport.width / 2, 1e-9));
    expect(quad.center.dy, closeTo(viewport.height / 2 + cover.y, 1e-9));
    expect(quad.width, closeTo(198 * cover.scaleX, 1e-9));
    expect(
      quad.angle,
      closeTo(composition.coverDeg * 3.141592653589793 / 180, 1e-9),
    );
    expect(box.paintBounds.right, greaterThanOrEqualTo(210));
    expect(tester.takeException(), isNull);
  }
  entrance.setActive(false);
  expect(clock.count, 0);
  now = 2000;
  entrance.setActive(true);
  expect(clock.count, 0);
  entrance.setCover(BravaisAlbumCoverState.pending);
  await tester.pump();
  expect(tester.takeException(), isNull);
  entrance.setCover(BravaisAlbumCoverState.ordinary);
  expect(clock.count, 1);
  now = 2680;
  clock.tick();
  await tester.pump();
  expect(clock.count, 0);
  entrance.setReducedMotion(true);
  expect(clock.count, 1);
  now = 2860;
  clock.tick();
  await tester.pump();
  expect(clock.count, 0);
  // A later asynchronous title adds only new index-keyed word runs.
  entrance.setReducedMotion(false);
  now = 4060;
  clock.tick();
  await tester.pump();
  expect(clock.count, 0);
  entrance.updateWords(['A', ' ', 'B', 'C']);
  expect(clock.count, 1);
  now = 5090;
  clock.tick();
  await tester.pump();
  expect(clock.count, 0);
  await tester.pumpWidget(const SizedBox());
  expect(clock.count, 0);
  entrance.dispose();
  clock.dispose();
}

class _AlbumFrames extends ChangeNotifier {
  int count = 0;
  @override
  void addListener(VoidCallback listener) {
    count++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    count--;
    super.removeListener(listener);
  }

  void tick() => notifyListeners();
}
