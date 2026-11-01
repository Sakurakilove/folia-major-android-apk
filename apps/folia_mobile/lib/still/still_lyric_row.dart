import 'package:flutter/widgets.dart';

import '../lyrics/lyric_types.dart';
import '../rendering/folia_typography.dart';
import '../theme/folia_theme.dart';
import 'still_text_shadow.dart';
import '../rendering/css_text.dart';

// Still's direct translation field is deliberate: unlike other styles it does not consume alternate subtitle mode.
class StillLyricRow extends StatelessWidget {
  const StillLyricRow({
    super.key,
    required this.line,
    required this.current,
    required this.theme,
    required this.subtitleTheme,
    required this.resolveColor,
    required this.lyricsFontScale,
    required this.subtitleFontScale,
    required this.hideTranslation,
    required this.fontsEpoch,
  });
  final LyricLine line;
  final bool current, hideTranslation;
  final FoliaTheme theme, subtitleTheme;
  final Color Function(String css) resolveColor;
  final double lyricsFontScale, subtitleFontScale;
  final int fontsEpoch;
  @override
  Widget build(BuildContext context) {
    final lyricPx = current ? 40.0 : 30.0, subtitlePx = current ? 24.0 : 20.0;
    final lyric = FoliaTypography.fromTheme(
      theme,
      fallbackWeight: current ? 700 : 600,
      height: current ? 1.25 : 36 / 30,
      fontsEpoch: fontsEpoch,
      locale: Localizations.maybeLocaleOf(context),
    );
    final subtitle = FoliaTypography.fromTheme(
      subtitleTheme,
      translation: true,
      fallbackWeight: current ? 500 : 400,
      height: current ? 32 / 24 : 28 / 20,
      fontsEpoch: fontsEpoch,
      locale: Localizations.maybeLocaleOf(context),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (line.text.isNotEmpty)
          Opacity(
            opacity: current ? 1 : .3,
            child: Transform.scale(
              scale: lyricsFontScale,
              child: StillTextShadow(
                offset: const Offset(0, 3),
                sigma: 3,
                alpha: .12,
                child: Text(
                  cssNormalText(line.text),
                  textAlign: TextAlign.center,
                  style: lyric
                      .style(lyricPx, color: resolveColor(theme.primaryColor))
                      .copyWith(letterSpacing: lyricPx * .02),
                ),
              ),
            ),
          ),
        if (line.translation?.isNotEmpty == true && !hideTranslation)
          Padding(
            padding: EdgeInsets.only(top: current ? 12 : 8),
            child: Opacity(
              opacity: current ? .8 : .3,
              child: Transform.scale(
                scale: lyricsFontScale * subtitleFontScale,
                child: StillTextShadow(
                  offset: const Offset(0, 1),
                  sigma: 2,
                  alpha: .15,
                  child: Text(
                    cssNormalText(line.translation!),
                    textAlign: TextAlign.center,
                    style: subtitle
                        .style(
                          subtitlePx,
                          color: resolveColor(subtitleTheme.secondaryColor),
                        )
                        .copyWith(letterSpacing: subtitlePx * .025),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
