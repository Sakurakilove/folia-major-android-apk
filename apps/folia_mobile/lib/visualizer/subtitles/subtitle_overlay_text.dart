import 'package:flutter/widgets.dart';

import '../../rendering/css_text.dart';
import '../../rendering/css_shadows.dart';
import '../../rendering/folia_typography.dart';
import '../../lyrics/subtitle_tracks.dart';
import '../../theme/folia_theme.dart';
import '../../theme/font_stacks.dart';
import 'subtitle_overlay_model.dart';
import 'subtitle_upcoming_line.dart';

// Source tracks, weights, secondary-size/opacity/gap and max widths; each style supplies the original clamp strings.
class SubtitleOverlayText extends StatelessWidget {
  const SubtitleOverlayText({
    super.key,
    required this.content,
    required this.theme,
    required this.resolveColor,
    required this.translationSize,
    required this.upcomingSize,
    required this.viewportWidth,
    required this.subtitleScale,
    required this.upcomingBlur,
    required this.fontsEpoch,
    this.subtitleTheme,
  });
  final SubtitleOverlayContent content;
  final FoliaTheme theme;
  final FoliaTheme? subtitleTheme;
  final Color Function(String) resolveColor;
  final String translationSize, upcomingSize;
  final double viewportWidth, subtitleScale;
  final bool upcomingBlur;
  final int fontsEpoch;
  @override
  Widget build(BuildContext context) {
    final sub = subtitleTheme ?? theme,
        color = resolveColor(theme.secondaryColor),
        background = resolveColor(theme.backgroundColor),
        locale = Localizations.maybeLocaleOf(context);
    TextStyle style(
      double font, {
      required bool translation,
      required int weight,
    }) =>
        FoliaTypography(
              // Upcoming rows inherit the lyric family but take their weight from subtitleTheme.
              families: resolveThemeFontFamilies(
                translation ? sub : theme,
                translation: translation,
              ),
              weight: resolveThemeFontWeight(sub, weight),
              height: 1.5,
              fontsEpoch: fontsEpoch,
              locale: locale,
            )
            .style(font, color: color)
            .copyWith(
              shadows: [
                cssTextShadow(
                  background.withValues(alpha: .24),
                  const Offset(0, 1),
                  2,
                ),
              ],
            );
    if (content.tracks.isNotEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 896),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < content.tracks.length; i++)
              (() {
                final secondary = i > 0,
                    font = resolveSubtitleClampPx(
                      scaleSubtitleFontSize(
                        translationSize,
                        subtitleScale,
                        secondary ? secondaryTrackSizeFactor : 1,
                      ),
                      viewportWidth,
                    );
                return Padding(
                  padding: EdgeInsets.only(
                    top: secondary ? secondaryTrackGapEm * font : 0,
                  ),
                  child: Opacity(
                    opacity: secondary ? secondaryTrackOpacity : 1,
                    child: Text(
                      cssNormalText(content.tracks[i].text),
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: style(
                        font,
                        translation: true,
                        weight: secondary
                            ? secondaryTrackFontWeightFallback
                            : 500,
                      ),
                    ),
                  ),
                );
              })(),
          ],
        ),
      );
    }
    final font = resolveSubtitleClampPx(
      scaleSubtitleFontSize(upcomingSize, subtitleScale),
      viewportWidth,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < content.upcomingLines.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 672),
              child: SubtitleUpcomingLine(
                text: content.upcomingLines[i].text,
                blur: upcomingBlur,
                style: style(font, translation: false, weight: 400),
              ),
            ),
          ),
      ],
    );
  }
}
