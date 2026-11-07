import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/bravais_camera.dart';
import 'package:folia_mobile/library/bravais/display/bravais_display.dart';
import 'package:folia_mobile/library/bravais/display/bravais_wall_data.dart';
import 'package:folia_mobile/library/bravais/display/bravais_wall_look.dart';
import 'package:folia_mobile/library/bravais/stage/bravais_wall_scene.dart';
import 'package:folia_mobile/library/bravais/stage/bravais_wall_selection.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_card_palette.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_item.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_tile_view.dart';
import 'package:folia_mobile/library/bravais/tiles/focus/bravais_focus_actions.dart';
import 'package:folia_mobile/library/bravais/tiles/skin/bravais_card_resources.dart';
import 'package:folia_mobile/library/wall/wall_types.dart';
import 'package:folia_mobile/library/wall/wall_paint_boundary.dart';

// One real bounded scene checks cull retention, reflow and hidden clock ownership inside the existing artwork case; no app/emulator/pixel suite.
Future<void> checkWallScenePlane(
  WidgetTester tester, {
  required BravaisCardResources resources,
  required BravaisCardActions actions,
  required BravaisCardPalette palette,
  required int Function() listeners,
  required void Function(double) setNow,
  required VoidCallback tick,
}) async {
  final camera = BravaisCamera(
        frames: resources.frames,
        nowMs: resources.nowMs,
        view: const WallView(500, 400, 1),
        center: const WallPoint(0, 0),
      ),
      display = ValueNotifier<BravaisDisplay?>(
        BravaisDisplay.create(
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
            ],
          ),
          null,
          wallLook: const BravaisWallLookSettings(BravaisWallLook.clear, 0),
        ),
      ),
      selection = ValueNotifier(const BravaisWallSelection());
  Future<void> mount(bool active, {bool poster = false}) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 500,
          height: 400,
          child: BravaisWallScene(
            camera: camera,
            display: display,
            selection: selection,
            resources: resources,
            actions: actions,
            noteAlbumSource: (_, _) {},
            palette: palette,
            dpr: 1,
            committedScale: 1,
            active: active,
            backdropOpen: true,
            posterWall: poster,
            posterTint: const Color(0xffff0000),
          ),
        ),
      ),
    ),
  );
  await mount(true);
  expect(tester.takeException(), isNull);
  expect(listeners(), 0);
  final before = tester
      .widgetList<BravaisTileView>(find.byType(BravaisTileView))
      .toList();
  expect(before, isNotEmpty);
  camera.moveTo(const WallPoint(20, 0));
  await tester.pump();
  final after = tester
      .widgetList<BravaisTileView>(find.byType(BravaisTileView))
      .toList();
  expect(before.length, after.length);
  for (var i = 0; i < before.length; i++) {
    expect(identical(before[i], after[i]), true);
  }
  final elements = {
    for (final element in tester.elementList(find.byType(BravaisTileView)))
      element.widget.key: element,
  };
  camera.moveTo(const WallPoint(240, 0), forceCull: true);
  await tester.pump();
  var retained = 0;
  for (final element in tester.elementList(find.byType(BravaisTileView))) {
    final old = elements[element.widget.key];
    if (old != null) {
      retained++;
      expect(identical(old, element), true);
    }
  }
  expect(retained, greaterThan(0));
  final slot = tester
      .widgetList<BravaisTileView>(find.byType(BravaisTileView))
      .first
      .slot;
  selection.value = BravaisWallSelection(
    expandedSlotKey: slot.key,
    focusedSlotKey: slot.key,
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
  expect(listeners(), greaterThan(0));
  await mount(false);
  expect(listeners(), 0);
  setNow(5000);
  await mount(true);
  expect(tester.takeException(), isNull);
  expect(listeners(), 0);
  expect(
    tester
        .renderObjectList<RenderWallPaintBoundary>(
          find.byType(WallPaintBoundary),
        )
        .any((box) => box.paintBounds.left < 0),
    true,
  );
  await mount(true, poster: true);
  expect(tester.takeException(), isNull);
  final inset = tester.renderObject<RenderWallFaceInset>(
    find.byWidgetPredicate((w) => w is WallFaceInset && w.inset == 10).first,
  );
  expect(inset.child!.size.width, inset.size.width - 20);
  setNow(6000);
  tick();
  await tester.pump();
  expect(tester.takeException(), isNull);
  expect(listeners(), 0);
  await tester.pumpWidget(const SizedBox());
  expect(listeners(), 0);
  camera.dispose();
  display.dispose();
  selection.dispose();
}
