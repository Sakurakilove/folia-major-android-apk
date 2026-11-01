import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/lyrics/lyric_types.dart';
import 'package:folia_mobile/playback/player_subtitle_bottom_signal.dart';
import 'package:folia_mobile/theme/folia_theme.dart';
import 'package:folia_mobile/visualizer/subtitles/visualizer_subtitle_overlay.dart';

// One headless lifecycle contract, not font/pixel acceptance or an emulator/UI suite.
class _Frames extends ChangeNotifier {
  bool get listening => hasListeners;
  void tick() => notifyListeners();
}

void main() {
  testWidgets(
    'subtitle follows bottom directly, retains exit content and releases its animation tickers',
    (tester) async {
      var now = 0.0;
      final offset = ValueNotifier(32.0),
          clearance = ValueNotifier(0.0),
          hidden = ValueNotifier(false),
          progressHidden = ValueNotifier(false),
          frames = _Frames();
      final bottom = PlayerSubtitleBottomSignal(
        offset: offset,
        androidClearance: clearance,
        chromeHidden: hidden,
        progressBarHidden: progressHidden,
        isPlayerHost: true,
        isAndroid: true,
        frames: frames,
        milliseconds: () => now,
      );
      final theme = FoliaTheme.fromJson({
        'name': 'Reference',
        'backgroundColor': '#111111',
        'primaryColor': '#eeeeee',
        'secondaryColor': '#dddddd',
        'accentColor': '#abcdef',
        'fontStyle': 'sans',
        'animationIntensity': 'normal',
      });
      Widget scene(bool show) => Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(360, 804)),
          child: DefaultTextStyle(
            style: const TextStyle(fontSize: 16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                VisualizerSubtitleOverlay(
                  showText: show,
                  activeLine: const LyricLine(
                    'source',
                    1,
                    3,
                    [],
                    translation: 'A readable translation',
                  ),
                  recentCompletedLine: null,
                  nextLines: const [],
                  theme: theme,
                  resolveColor: (_) => const Color(0xffeeeeee),
                  bottom: bottom,
                  translationFontSize: 'clamp(1.125rem, 2.600vw, 1.250rem)',
                  upcomingFontSize: 'clamp(0.875rem, 2.000vw, 1.000rem)',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(scene(true));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('A readable translation'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      offset.value = 123;
      await tester.pump();
      expect(
        tester.widget<Positioned>(find.byType(Positioned).first).bottom,
        203,
      );
      expect(
        frames.listening,
        false,
      ); // A direct baseline drag must not start a follower.
      hidden.value = true;
      expect(frames.listening, true);
      now = 16.6;
      frames.tick();
      expect(bottom.value, inExclusiveRange(32, 203));
      now = 2000;
      frames.tick();
      await tester.pump();
      expect(bottom.value, 32);
      expect(frames.listening, false);
      await tester.pumpWidget(scene(false));
      expect(find.text('A readable translation'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('A readable translation'), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      bottom.dispose();
      offset.dispose();
      clearance.dispose();
      hidden.dispose();
      progressHidden.dispose();
      frames.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
