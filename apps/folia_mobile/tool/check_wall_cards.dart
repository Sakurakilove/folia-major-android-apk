import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/i18n/folia_strings.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_control.dart';
import 'package:folia_mobile/library/bravais/tiles/focus/bravais_focus_actions.dart';
import 'package:folia_mobile/library/bravais/tiles/focus/bravais_focus_body.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_item.dart';
import 'package:folia_mobile/library/wall/wall_typography.dart';
import 'package:folia_mobile/rendering/folia_icons.dart';
import 'package:folia_mobile/visualizer/motion/css_transition.dart';

import 'wall_card_motion_contract.dart';

// One focused native layout/action/lifecycle check. It does not certify Chromium font metrics, balanced line breaks or full wall pixels.
void main() {
  testWidgets(
    'expanded source card keeps current toggle, capabilities, menu and finite reveal',
    (tester) async {
      final transition = CssNumericTransition(.45);
      transition.setTarget(.7, 0, const CssTransitionSpec(140));
      transition.advance(70);
      expect(transition.value, closeTo(.6506008468962143, 1e-10));
      transition.setTarget(.45, 70, const CssTransitionSpec(140));
      transition.advance(182.337);
      expect(transition.value, .45);
      expect(transition.isAnimating, false);
      final strings = (await tester.runAsync(() => FoliaStrings.load('en')))!,
          clock = _Frames(),
          playing = ValueNotifier(false),
          calls = <String>[];
      var now = 0.0;
      final actions = BravaisCardActions(
        activate: (s) => calls.add('activate:$s'),
        play: (s) => calls.add('play:$s'),
        enqueue: (s) => calls.add('queue:$s'),
        canOpenAlbum: (_) => true,
        openAlbum: (s) => calls.add('album:$s'),
        canOpenArtist: (_, i) => i == 0,
        openArtist: (s, i) => calls.add('artist:$s:$i'),
        menuFor: (_) => const [
          BravaisEntryMenuItem('remove', 'Remove', danger: true),
        ],
        runMenu: (s, a) => calls.add('menu:$s:$a'),
        hover: (_) {},
        togglesCurrent: true,
        enterPlayback: () => calls.add('enter'),
      );
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 816,
              height: 816,
              child: BravaisFocusBody(
                slotKey: 'a',
                item: const BravaisItem(
                  key: 'song',
                  kind: BravaisItemKind.track,
                  title: 'Source title',
                  subtitle: 'Artist',
                  badge: '01',
                  album: 'Album',
                  artists: ['Artist', 'Other'],
                  durationLabel: '3:15',
                  unavailable: true,
                ),
                queued: true,
                current: true,
                titleWidth: 816,
                viewportWidth: 1400,
                actions: actions,
                typography: const WallTypography(),
                strings: strings,
                ink: const Color(0xffffffff),
                accent: const Color(0xffff0000),
                frames: clock,
                nowMs: () => now,
                isPlaying: playing,
                entersLattice: false,
                reducedMotion: false,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(clock.count, 1);
      now = 380;
      clock.tick();
      await tester.pump();
      expect(clock.count, 0);
      playing.value = true;
      await tester.pump();
      final pause = find.byWidgetPredicate(
        (w) => w is BravaisChromeButton && w.label == 'Pause',
      );
      expect(pause, findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is FoliaIcon && w.name == 'Pause' && w.filled,
        ),
        findsOneWidget,
      );
      await tester.tap(pause);
      expect(calls, ['play:a']);
      final queue = tester
          .widgetList<BravaisChromeButton>(find.byType(BravaisChromeButton))
          .where((w) => w.label == 'In queue')
          .single;
      expect(queue.onPressed, isNull);
      await tester.tap(find.text('Artist'));
      expect(calls.last, 'artist:a:0');
      await tester.tap(find.text('Album'));
      expect(calls.last, 'album:a');
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is BravaisChromeButton && w.expanded == false,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Remove'));
      await tester.pump();
      expect(calls.last, 'menu:a:remove');
      expect(find.text('Remove'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(clock.count, 0);
      clock.dispose();
      playing.dispose();
      await checkWallCardMotion(tester);
    },
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
