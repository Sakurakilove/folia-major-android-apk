import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_card_look.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_card_palette.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_item.dart';
import 'package:folia_mobile/library/bravais/tiles/skin/bravais_card_layer.dart';
import 'package:folia_mobile/library/bravais/tiles/skin/bravais_card_skin.dart';
import 'package:folia_mobile/library/bravais/tiles/artwork/bravais_album_art_motion.dart';
import 'package:folia_mobile/library/bravais/bravais_album_art.dart';
import 'package:folia_mobile/library/wall/wall_css_filter.dart';
import 'package:folia_mobile/visualizer/motion/css_transition.dart';

// Extend the existing small card check, not a full UI suite: retained child, finite clocks, filter ordering and newly created shard pseudo-elements.
Future<void> checkWallCardMotion(WidgetTester tester) async {
  final clock = _Frames();
  var now = 0.0, builds = 0;
  const palette = BravaisCardPalette(
    background: Color(0xff070707),
    ink: Color(0xfff7f4ee),
    accent: Color(0xfffd5c47),
    secondary: Color(0xff6a48ff),
    daylight: false,
  );
  Future<void> mount(bool hover, {bool active = true, bool dimmed = false}) =>
      tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 136,
              height: 128,
              child: BravaisCardSkin(
                look: BravaisCardLook(
                  face: BravaisCardFace(
                    BravaisItem(
                      key: 'a',
                      kind: BravaisItemKind.track,
                      title: 'title',
                      subtitle: '',
                      badge: '1',
                      dimmed: dimmed,
                    ),
                    BravaisTileKind.content,
                  ),
                  palette: palette,
                  width: 136,
                  height: 128,
                  hovered: hover,
                ),
                frames: clock,
                nowMs: () => now,
                active: active,
                copy: Builder(
                  builder: (_) {
                    builds++;
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ),
        ),
      );
  await mount(false);
  expect(clock.count, 0);
  await mount(true);
  final rendered = tester.renderObject<RenderBravaisCard>(
        find.byType(BravaisCardLayer),
      ),
      initialBuilds = builds;
  expect(clock.count, 1);
  now = 150;
  clock.tick();
  await tester.pump();
  expect(builds, initialBuilds);
  expect(rendered.transform.entry(0, 0), greaterThan(1));
  expect(rendered.transform.entry(0, 0), lessThan(1.1176));
  now = 600;
  clock.tick();
  await tester.pump();
  expect(clock.count, 0);
  expect(rendered.transform.entry(0, 0), 1.1176);
  await mount(true, dimmed: true);
  // Different non-empty function lists do not start an ordinary CSS transition.
  expect(rendered.nativeFilter, isNotNull);
  await mount(true, dimmed: true, active: false);
  expect(clock.count, 0);
  now = 1000;
  await mount(true, dimmed: true);
  expect(clock.count, 0);
  await tester.pumpWidget(const SizedBox());
  expect(clock.count, 0);
  clock.dispose();

  final artClock = _Frames();
  now = 0;
  final art = BravaisAlbumArtMotion(
    frames: artClock,
    nowMs: () => now,
    mode: BravaisArtMode.shard,
    placement: const BravaisArtPlacement(100, 0, 0),
    accent: palette.accent,
    block: palette.background,
    restored: false,
  );
  void listener() {}
  art.addListener(listener);
  art.update(
    mode: BravaisArtMode.shard,
    placement: const BravaisArtPlacement(100, 0, 0),
    accent: palette.accent,
    block: palette.background,
    restored: true,
  );
  expect(art.value.multiply, false);
  now = 130;
  artClock.tick();
  final track = CssNumericTransition(1)
    ..setTarget(0, 0, const CssTransitionSpec(260));
  track.advance(now);
  expect(art.value.grayscale, closeTo(track.value, 1e-12));
  art.update(
    mode: BravaisArtMode.mosaic,
    placement: const BravaisArtPlacement(100, 0, 0),
    accent: palette.accent,
    block: palette.background,
    restored: false,
  );
  expect(art.value.grayscale, greaterThan(0));
  expect(art.value.darkOpacity, 0);
  expect(art.value.dotOpacity, 0);
  now = 400;
  artClock.tick();
  expect(artClock.count, 0);
  art.dispose();
  artClock.dispose();
  expect(
    const WallCssFilter([WallFilterOp(WallFilterKind.saturate, 1.08)])
        .compatible(
          const WallCssFilter([WallFilterOp(WallFilterKind.grayscale, 1)]),
        ),
    false,
  );
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
