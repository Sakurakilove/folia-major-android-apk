import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/lyrics/lyric_types.dart';
import 'package:folia_mobile/theme/folia_theme.dart';
import 'package:folia_mobile/visualizer/subtitles/visualizer_subtitle_overlay.dart';

// One headless lifecycle contract, not font/pixel acceptance or an emulator/UI suite.
void main() {
  testWidgets(
    'subtitle follows bottom directly, retains exit content and releases its animation tickers',
    (tester) async {
      final bottom = ValueNotifier(112.0),
          theme = FoliaTheme.fromJson({
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
      bottom.value = 203;
      await tester.pump();
      expect(
        tester.widget<Positioned>(find.byType(Positioned).first).bottom,
        203,
      );
      await tester.pumpWidget(scene(false));
      expect(find.text('A readable translation'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('A readable translation'), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      bottom.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
