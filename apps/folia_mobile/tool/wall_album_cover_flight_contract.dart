import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/cover/bravais_cover_flights.dart';
import 'package:folia_mobile/library/bravais/cover/bravais_cover_memory.dart';
import 'package:folia_mobile/library/bravais/cover/bravais_cover_overlay.dart';
import 'package:folia_mobile/library/bravais/cover/bravais_cover_tiles.dart';
import 'package:folia_mobile/library/bravais/poster/bravais_album_composition.dart';
import 'package:folia_mobile/library/bravais/poster/album/bravais_album_cover_flight.dart';
import 'package:folia_mobile/library/bravais/poster/album/bravais_album_entrance.dart';
import 'package:folia_mobile/library/bravais/poster/album/bravais_album_motion.dart';
import 'package:folia_mobile/library/bravais/poster/album/bravais_album_flying_cover.dart';

// One actual mounted wall/figure/overlay path extends the existing native case. No image IO, full page, fonts, color or device acceptance is implied.
Future<void> checkWallAlbumCoverFlight(
  WidgetTester tester, {
  required Widget wall,
  required BravaisCoverTiles tiles,
  required BravaisCoverMemory memory,
  required String slotKey,
}) async {
  var now = 0.0, current = 'album', builds = 0;
  final frames = _AlbumCoverFrames(),
      entrance = BravaisAlbumEntrance(
        frames: frames,
        nowMs: () => now,
        words: const [],
      ),
      flights = BravaisCoverFlights(frames: frames, nowMs: () => now),
      tile = tiles.find(slotKey)!;
  const url = 'https://example.test/album.jpg';
  memory.note(
    cardKey: tile.cardKey()!,
    slotKey: slotKey,
    coverUrl: url,
    quad: tile.measure(),
  );
  VoidCallback? settle;
  var cancelled = false;
  final controller = BravaisAlbumCoverFlight(
    layerKey: 'album',
    coverUrl: url,
    entrance: entrance,
    memory: memory,
    flights: flights,
    tiles: tiles,
    currentLayerKey: () => current,
    reducedMotion: () => false,
    schedule: (delay, run) {
      expect(delay, const Duration(milliseconds: 1300));
      settle = run;
      return () => cancelled = true;
    },
  );
  expect(flights.entries.value.length, 1);
  expect(
    frames.count,
    0,
  ); // Prepared entry cannot run lost/ready before layout.
  expect(entrance.sample(BravaisAlbumPart.cover).visible, false);
  Future<void> mount(bool poster) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 500, height: 200, child: wall),
          ),
          if (poster)
            Center(
              child: Builder(
                builder: (_) {
                  builds++;
                  return BravaisAlbumFlyingCover(
                    controller: controller,
                    posterSize: const Size(400, 600),
                    composition: resolveBravaisAlbumComposition('album:source'),
                    provider: null,
                  );
                },
              ),
            ),
          BravaisCoverOverlay(
            key: const ValueKey('flights'),
            flights: flights,
            imageFor: (_) => null,
          ),
        ],
      ),
    ),
  );
  try {
    await mount(true);
    expect(settle, isNotNull);
    final retained = controller.anchor.currentContext!.findRenderObject();
    for (final at in [320.0, 640.0, 656.0, 1200.0]) {
      now = at;
      frames.tick();
      await tester.pump();
      expect(
        identical(
          controller.anchor.currentContext!.findRenderObject(),
          retained,
        ),
        true,
      );
      expect(builds, 1);
      expect(tester.takeException(), isNull);
    }
    expect(entrance.sample(BravaisAlbumPart.cover).visible, true);
    expect(flights.entries.value, isEmpty);
    expect(frames.count, 0);
    now = 1300;
    settle!();
    current = 'artist';
    await mount(false);
    expect(cancelled, true);
    expect(frames.count, 1);
    now = 1316;
    frames.tick();
    await tester.pump();
    expect(flights.entries.value.length, 1);
    for (final at in [1876.0, 2076.0]) {
      now = at;
      frames.tick();
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    expect(flights.entries.value, isEmpty);
    expect(frames.count, 0);
  } finally {
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    flights.dispose();
    entrance.dispose();
    frames.dispose();
  }
}

class _AlbumCoverFrames extends ChangeNotifier {
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
