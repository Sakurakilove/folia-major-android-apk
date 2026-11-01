import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

import '../../lyrics/lyric_types.dart';
import '../../lyrics/subtitle_tracks.dart';
import '../../theme/folia_theme.dart';
import '../motion/motion_curves.dart';
import 'subtitle_overlay_glow.dart';
import 'subtitle_overlay_model.dart';
import 'subtitle_overlay_text.dart';
import 'subtitle_translation_entry.dart';

// Shared native subtitle composition; the host owns the live bottom geometry, including player-presence spring and direct dragging.
class VisualizerSubtitleOverlay extends StatefulWidget {
  const VisualizerSubtitleOverlay({
    super.key,
    required this.showText,
    required this.activeLine,
    required this.recentCompletedLine,
    required this.nextLines,
    required this.theme,
    required this.resolveColor,
    required this.bottom,
    required this.translationFontSize,
    required this.upcomingFontSize,
    this.subtitleTheme,
    this.subtitleFontScale = 1,
    this.opacity = .6,
    this.overlayBackground = true,
    this.upcomingBlur = true,
    this.hideTranslationSubtitle = false,
    this.showSubtitleTranslation = true,
    this.subtitleContentMode,
    this.fontsEpoch = 0,
  });
  final bool showText,
      overlayBackground,
      upcomingBlur,
      hideTranslationSubtitle,
      showSubtitleTranslation;
  final LyricLine? activeLine, recentCompletedLine;
  final List<LyricLine> nextLines;
  final FoliaTheme theme;
  final FoliaTheme? subtitleTheme;
  final Color Function(String) resolveColor;
  final ValueListenable<double> bottom;
  final String translationFontSize, upcomingFontSize;
  final double subtitleFontScale, opacity;
  final SubtitleContentMode? subtitleContentMode;
  final int fontsEpoch;
  @override
  State<VisualizerSubtitleOverlay> createState() =>
      _VisualizerSubtitleOverlayState();
}

class _VisualizerSubtitleOverlayState extends State<VisualizerSubtitleOverlay>
    with SingleTickerProviderStateMixin {
  late final _clock =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 240),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_wanted && mounted) {
          setState(() {
            _retained = null;
          });
        }
      });
  static const _ease = CssBezierCurve(0, 0, .58, 1),
      _positionEase = MotionBezierCurve(0, 0, .58, 1);
  bool _wanted = false;
  double _alphaFrom = 0, _alphaTo = 0, _yFrom = 20, _yTo = 20;
  Widget? _retained;
  SubtitleOverlayContent _content() => resolveSubtitleOverlayContent(
    showText: widget.showText,
    activeLine: widget.activeLine,
    recentCompletedLine: widget.recentCompletedLine,
    nextLines: widget.nextLines,
    hideTranslationSubtitle: widget.hideTranslationSubtitle,
    showSubtitleTranslation: widget.showSubtitleTranslation,
    subtitleContentMode: widget.subtitleContentMode,
  );
  double get _t => _ease.transform(_clock.value);
  double get _alpha => _alphaFrom + (_alphaTo - _alphaFrom) * _t;
  double get _y =>
      _yFrom + (_yTo - _yFrom) * _positionEase.transform(_clock.value);
  void _sync() {
    final wanted = _content().shouldRenderOverlay,
        alpha = wanted ? widget.opacity : 0.0;
    if (wanted == _wanted && alpha == _alphaTo) return;
    final currentAlpha = _alpha, currentY = _y;
    _wanted = wanted;
    _alphaFrom = currentAlpha;
    _yFrom = currentY;
    _alphaTo = alpha;
    _yTo = wanted ? 0 : 20;
    _clock.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(VisualizerSubtitleOverlay old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _content();
    if (_wanted) {
      final text = SubtitleOverlayText(
        content: content,
        theme: widget.theme,
        subtitleTheme: widget.subtitleTheme,
        resolveColor: widget.resolveColor,
        translationSize: widget.translationFontSize,
        upcomingSize: widget.upcomingFontSize,
        viewportWidth: MediaQuery.sizeOf(context).width,
        subtitleScale: widget.subtitleFontScale,
        upcomingBlur: widget.upcomingBlur,
        fontsEpoch: widget.fontsEpoch,
      );
      final active = widget.activeLine?.start,
          key = active != null && active != 0 && !active.isNaN
              ? active
              : widget.recentCompletedLine?.start;
      _retained = content.subtitleText == null && content.upcomingLines.isEmpty
          ? const SizedBox.shrink()
          : RepaintBoundary(
              child: SubtitleOverlayGlow(
                background: widget.resolveColor(widget.theme.backgroundColor),
                enabled: widget.overlayBackground,
                child: content.subtitleText != null
                    ? SubtitleTranslationEntry(key: ValueKey(key), child: text)
                    : text,
              ),
            );
    }
    if (_retained == null && !_wanted) return const SizedBox.shrink();
    return ValueListenableBuilder<double>(
      valueListenable: widget.bottom,
      child: AnimatedBuilder(
        animation: _clock,
        child: _retained,
        builder: (context, child) => IgnorePointer(
          child: Opacity(
            opacity: _alpha.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, _y),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.center,
                  heightFactor: 1,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
      builder: (context, bottom, child) =>
          Positioned(left: 0, right: 0, bottom: bottom, child: child!),
    );
  }
}
