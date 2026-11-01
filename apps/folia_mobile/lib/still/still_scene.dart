import 'package:flutter/widgets.dart';

import '../lyrics/lyric_document.dart';
import '../theme/folia_theme.dart';
import 'still_fog.dart';
import 'still_lyric_row.dart';

// VisualizerStill.tsx's independent three-row composition; it retains the last effective line through lyric gaps.
class StillScene extends StatefulWidget {
  const StillScene({
    super.key,
    required this.document,
    required this.currentLineIndex,
    required this.theme,
    required this.resolveColor,
    this.subtitleTheme,
    this.lyricsFontScale = 1,
    this.subtitleFontScale = 1,
    this.hideTranslationSubtitle = false,
    this.isDaylight = false,
    this.showText = true,
    this.fontsEpoch = 0,
  });
  final LyricDocument document;
  final int currentLineIndex, fontsEpoch;
  final FoliaTheme theme;
  final FoliaTheme? subtitleTheme;
  final Color Function(String css) resolveColor;
  final double lyricsFontScale, subtitleFontScale;
  final bool hideTranslationSubtitle, isDaylight, showText;
  @override
  State<StillScene> createState() => _StillSceneState();
}

class _StillSceneState extends State<StillScene> {
  late int _effectiveIndex = widget.currentLineIndex < 0
      ? 0
      : widget.currentLineIndex;
  @override
  void didUpdateWidget(StillScene old) {
    super.didUpdateWidget(old);
    if (widget.currentLineIndex != -1) {
      _effectiveIndex = widget.currentLineIndex;
    } else if (_effectiveIndex >= widget.document.lines.length) {
      _effectiveIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // This mode intentionally does not mount any shared background, exactly as its original registry entry specifies.
      IgnorePointer(
        child: CustomPaint(painter: StillFog(daylight: widget.isDaylight)),
      ),
      if (widget.showText)
        IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.only(left: 48, right: 48, bottom: 64),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var offset = -1; offset <= 1; offset++) ...[
                    if (offset != -1) const SizedBox(height: 32),
                    if (_effectiveIndex + offset < 0 ||
                        _effectiveIndex + offset >=
                            widget.document.lines.length)
                      const SizedBox(height: 80)
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 896),
                        child: SizedBox(
                          width: double.infinity,
                          child: StillLyricRow(
                            key: ValueKey(_effectiveIndex + offset),
                            line:
                                widget.document.lines[_effectiveIndex + offset],
                            current: offset == 0,
                            theme: widget.theme,
                            subtitleTheme: widget.subtitleTheme ?? widget.theme,
                            resolveColor: widget.resolveColor,
                            lyricsFontScale: widget.lyricsFontScale,
                            subtitleFontScale: widget.subtitleFontScale,
                            hideTranslation: widget.hideTranslationSubtitle,
                            fontsEpoch: widget.fontsEpoch,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
