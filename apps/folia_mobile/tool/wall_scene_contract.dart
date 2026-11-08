import 'dart:ffi';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/artwork/cover_url.dart';
import 'package:folia_mobile/artwork/native_url.dart';
import 'package:folia_mobile/artwork/wall_artwork_store.dart';
import 'package:folia_mobile/i18n/folia_strings.dart';
import 'package:folia_mobile/library/bravais/bravais_frame.dart';
import 'package:folia_mobile/library/bravais/cover/bravais_cover_tiles.dart';
import 'package:folia_mobile/library/bravais/cover/bravais_cover_memory.dart';
import 'package:folia_mobile/library/bravais/display/bravais_display.dart';
import 'package:folia_mobile/library/bravais/display/bravais_wall_data.dart';
import 'package:folia_mobile/library/bravais/display/bravais_wall_look.dart';
import 'package:folia_mobile/library/bravais/stage/bravais_wall_view.dart';
import 'package:folia_mobile/library/bravais/tiles/artwork/bravais_art_program.dart';
import 'package:folia_mobile/library/bravais/tiles/artwork/bravais_artwork_samples.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_card_palette.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_item.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_tile_input.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_tile_view.dart';
import 'package:folia_mobile/library/bravais/tiles/focus/bravais_focus_actions.dart';
import 'package:folia_mobile/library/bravais/tiles/skin/bravais_card_resources.dart';
import 'package:folia_mobile/library/wall/wall_slots.dart';
import 'package:folia_mobile/library/wall/wall_types.dart';
import 'package:folia_mobile/library/wall/wall_typography.dart';

import 'wall_scene_plane_contract.dart';
import 'wall_tile_input_contract.dart';
import 'wall_album_cover_flight_contract.dart';

// Extend the existing small artwork check with real wall assembly/parent data/resource cleanup; no full app or screenshot suite.
Future<void> checkWallSceneContract(WidgetTester tester) async {
  var now = 0.0;
  final activations = <String>[];
  final owned = await tester.runAsync(
    () async => (
      program: await BravaisArtProgram.load(),
      strings: await FoliaStrings.load('en'),
    ),
  );
  final clock = _Frames(),
      playing = ValueNotifier(false),
      policy = CoverUrlPolicy(
        NativeUrlLibrary(
          library: DynamicLibrary.open(
            Platform.environment['FOLIA_URL_LIBRARY']!,
          ),
        ),
      ),
      store = WallArtworkStore(
        policy: policy,
        loadBuffer: (_, _) => throw StateError('Unexpected artwork IO'),
      ),
      samples = BravaisArtworkSamples(
        urls: policy,
        sample: (_) => throw StateError('Unexpected sample IO'),
      ),
      coverMemory = BravaisCoverMemory(urls: policy, nowMs: () => now),
      coverTiles = BravaisCoverTiles(coverMemory),
      pointer = BravaisPointerHistory()..attach();
  const palette = BravaisCardPalette(
    background: Color(0xff070707),
    ink: Color(0xfff7f4ee),
    accent: Color(0xfffd5c47),
    secondary: Color(0xff6a48ff),
    daylight: false,
  );
  final resources = BravaisCardResources(
        store: store,
        samples: samples,
        program: owned!.program,
        frames: clock,
        nowMs: () => now,
        isPlaying: playing,
        typography: const WallTypography(),
        strings: owned.strings,
        albumAccent: palette.accent,
        albumBlock: palette.background,
        coverTiles: coverTiles,
      ),
      actions = BravaisCardActions(
        activate: activations.add,
        play: (_) {},
        enqueue: (_) {},
        canOpenAlbum: (_) => false,
        openAlbum: (_) {},
        canOpenArtist: (_, _) => false,
        openArtist: (_, _) {},
        menuFor: (_) => const [],
        runMenu: (_, _) {},
        hover: (_) {},
        togglesCurrent: false,
      ),
      frame = ValueNotifier(
        computeBravaisFrame(
          center: const WallPoint(0, 0),
          view: const WallView(500, 200, 1),
          anchorX: null,
          openWidth: 0,
          contentWidth: 0,
          hidden: false,
        ),
      ),
      display = BravaisDisplay.create(
        const BravaisWallData(
          key: 'home:playlist',
          sessionKey: 'home',
          mode: BravaisLayerMode.infinite,
          items: [
            BravaisItem(
              key: 'track',
              kind: BravaisItemKind.track,
              title: 'Track',
              subtitle: 'Artist',
              badge: '01',
            ),
            BravaisItem(
              key: 'album',
              kind: BravaisItemKind.album,
              title: 'Album',
              subtitle: 'Artist',
              badge: 'Album',
            ),
            BravaisItem(
              key: 'artist',
              kind: BravaisItemKind.artist,
              title: 'Artist',
              subtitle: '',
              badge: 'Artist',
            ),
          ],
        ),
        null,
      );
  Future<void> mount({bool poster = false}) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 500,
          height: 200,
          child: BravaisWallView(
            slots: const [
              WallSlot(0, 0, 0, 0, 0, 128, 128, 1),
              WallSlot(0, 0, 1, 136, 0, 128, 128, 1),
              WallSlot(0, 0, 2, 272, 0, 128, 128, 1),
            ],
            display: display,
            frame: frame,
            dpr: 1,
            committedScale: 1,
            viewportWidth: 500,
            resources: resources,
            actions: actions,
            pointerHistory: pointer,
            consumeDrag: () => false,
            noteAlbumSource: (_, _) {},
            palette: palette,
            tinted: true,
            posterWall: poster,
          ),
        ),
      ),
    ),
  );
  await mount();
  expect(tester.takeException(), isNull);
  expect(find.byType(BravaisTileView), findsNWidgets(3));
  final before = tester
      .widgetList<BravaisTileView>(find.byType(BravaisTileView))
      .toList();
  final captured = coverTiles.find(before[1].slot.key)!;
  expect(captured.measure()!.width, closeTo(128, 1e-9));
  expect(captured.cardKey(), before[1].look.face.item?.key);
  coverTiles.note(
    before[1].slot.key,
    'source-album',
    'https://example.test/a.jpg',
  );
  final source = coverMemory.take(
    'https://example.test/a.jpg',
    reducedMotion: false,
  )!;
  expect(source.cardKey, 'source-album');
  expect(source.quad.width, closeTo(128, 1e-9));
  expect(clock.count, 0);
  frame.value = computeBravaisFrame(
    center: const WallPoint(20, 0),
    view: const WallView(500, 200, 1),
    anchorX: null,
    openWidth: 0,
    contentWidth: 0,
    hidden: false,
  );
  await tester.pump();
  final after = tester
      .widgetList<BravaisTileView>(find.byType(BravaisTileView))
      .toList();
  for (var i = 0; i < before.length; i++) {
    expect(identical(before[i], after[i]), true);
  }
  expect(identical(coverTiles.find(before[1].slot.key), captured), true);
  final oldCenter = captured.measure()!.center;
  await mount(poster: true);
  expect(captured.measure()!.width, closeTo(108, 1e-9));
  expect(captured.measure()!.center, oldCenter);
  expect(tester.takeException(), isNull);
  await mount();
  await checkWallTileInput(
    tester,
    activations: activations,
    slotKey: before.first.slot.key,
    mount: (poster) => mount(poster: poster),
    setNow: (value) => now = value,
    tick: clock.tick,
  );
  await checkWallAlbumCoverFlight(
    tester,
    wall: tester.widget<BravaisWallView>(find.byType(BravaisWallView)),
    tiles: coverTiles,
    memory: coverMemory,
    slotKey: before[1].slot.key,
  );
  await tester.pumpWidget(const SizedBox());
  expect(clock.count, 0);
  expect(coverTiles.find(before[1].slot.key), isNull);
  expect(captured.measure(), isNull);
  expect(captured.cardKey(), isNull);
  await checkWallScenePlane(
    tester,
    resources: resources,
    actions: actions,
    palette: palette,
    listeners: () => clock.count,
    setNow: (value) => now = value,
    tick: clock.tick,
  );
  pointer.dispose();
  samples.dispose();
  store.dispose();
  owned.program.dispose();
  playing.dispose();
  frame.dispose();
  clock.dispose();
  coverTiles.dispose();
}

class _Frames extends ChangeNotifier {
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
