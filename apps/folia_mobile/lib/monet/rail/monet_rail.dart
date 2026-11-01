import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../lyrics/lyric_document.dart';
import '../../lyrics/subtitle_tracks.dart';
import '../../lyrics/visualizer_runtime.dart';
import '../../rendering/repaint_signal.dart';
import '../../rendering/word_coloring.dart';
import '../../rendering/css_shadows.dart';
import '../../visualizer/transitions/scene_first_frame.dart';
import '../../theme/folia_theme.dart';
import '../../theme/font_stacks.dart';
import '../glyph_cache.dart';
import '../monet_lyrics_model.dart';
import 'monet_rail_layout.dart';
import 'monet_rail_motion.dart';
import 'monet_text_measurement.dart';
import '../../rendering/folia_typography.dart';
import 'monet_rail_painter.dart';
import 'monet_paint_row.dart';

part 'monet_rail_configuration.dart';
part 'monet_rail_inputs.dart';
part 'monet_rail_selection.dart';
part 'monet_rail_preparation.dart';

// Faithful rail assembly: source selection/layout/motion, native masks and local clocks; no frame channels.
class MonetRail extends StatefulWidget {
  const MonetRail({
    super.key,
    required this.document,
    required this.position,
    required this.seconds,
    required this.frames,
    required this.tokenProgram,
    required this.theme,
    required this.resolveColor,
    required this.lyricFontPx,
    required this.inactiveFontPx,
    required this.translationFontPx,
    this.subtitleTheme,
    this.subtitleContentMode = SubtitleContentMode.translation,
    this.keywordColoringEnabled = true,
    this.layoutScale = 1,
    this.fontsEpoch = 0,
    this.onLineSeek,
    this.seekDisabled = false,
    this.active = true,
  });
  final LyricDocument document;
  final double Function() position, seconds;
  final Listenable frames;
  final ui.FragmentProgram tokenProgram;
  final FoliaTheme theme;
  final FoliaTheme? subtitleTheme;
  final Color Function(String css) resolveColor;
  final double lyricFontPx, inactiveFontPx, translationFontPx, layoutScale;
  final int fontsEpoch;
  final SubtitleContentMode subtitleContentMode;
  final bool keywordColoringEnabled, seekDisabled, active;
  final void Function(double time)? onLineSeek;
  @override
  State<MonetRail> createState() => _MonetRailState();
}

class _MonetRailState extends State<MonetRail> {
  final _cache = GlyphCache(), _repaint = RepaintSignal();
  final _layouts = <String, MonetMeasuredLineLayout>{},
      _rows = <String, MonetPaintRow>{};
  List<MonetPaintRow> _ordered = [];
  late MonetNativeTextMeasurement _measure;
  late FoliaTypography _lyric, _subtitle, _secondarySubtitle;
  late String _lyricStack, _subtitleStack;
  late Color _primary, _accent, _background;
  late List<WordColorMatcher> _matchers;
  Listenable? _attached;
  SceneFirstFrameReport? _firstFrame;
  Size _size = Size.zero;
  Timer? _manualReset;
  int? _manualAnchor, _pointer;
  int _currentIndex = -2, _latestStart = -2;
  double? _lastPaintPosition, _touchLastY;
  double _touchAccum = 0, _wheelAccum = 0;
  int _touchDirection = 0, _wheelDirection = 0;
  bool _visible = true,
      _needsLayout = true,
      _building = false,
      _hasExiting = false,
      _hasPopulatedRail = false;

  bool get _canSeek => widget.onLineSeek != null && !widget.seekDisabled;
  double get _glow => (widget.lyricFontPx * 1.2).roundToDouble();
  @override
  void initState() {
    super.initState();
    _configuration();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _firstFrame = SceneFirstFrameScope.maybeOf(context);
    _firstFrame?.claim();
    _configuration();
    _attach();
  }

  @override
  void didUpdateWidget(MonetRail old) {
    super.didUpdateWidget(old);
    if (old.document != widget.document) {
      _manualAnchor = null;
      _manualReset?.cancel();
    }
    _configuration();
    _attach();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _attach() {
    final wanted = widget.active && _visible ? widget.frames : null;
    if (_attached == wanted) return;
    _attached?.removeListener(_frame);
    _attached = wanted;
    _attached?.addListener(_frame);
  }

  @override
  void dispose() {
    _attached?.removeListener(_frame);
    _manualReset?.cancel();
    for (final row in _rows.values) {
      row.dispose();
    }
    _cache.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).height * .52).clamp(
      280.0,
      math
          .max(
            520 * widget.layoutScale,
            widget.lyricFontPx * 1.18 * monetRailMinRows,
          )
          .roundToDouble(),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (780 * widget.layoutScale).roundToDouble(),
      ),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            _building = true;
            try {
              if (_size != size || _needsLayout) {
                _size = size;
                _needsLayout = false;
                _sync(force: true);
              }
            } finally {
              _building = false;
            }
            return Listener(
              onPointerDown: _pointerDown,
              onPointerMove: _pointerMove,
              onPointerUp: _pointerEnd,
              onPointerCancel: _pointerEnd,
              onPointerSignal: _wheel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _seek(details.localPosition),
                onVerticalDragUpdate: (_) {},
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: MonetRailPainter(
                      rows: () => _ordered,
                      cache: _cache,
                      position: widget.position,
                      seconds: widget.seconds,
                      primary: _primary,
                      accent: _accent,
                      background: _background,
                      fontPx: widget.lyricFontPx,
                      glowBuffer: _glow,
                      repaint: _repaint,
                      onContentPainted: () => _firstFrame?.drawn(),
                      onSeek: _canSeek
                          ? (time) {
                              widget.onLineSeek!(time);
                              _manualAnchor = null;
                              _manualReset?.cancel();
                              _sync(force: true);
                            }
                          : null,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
