import 'package:flutter/widgets.dart';

import '../../../wall/wall_box_shadows.dart';
import '../../../wall/wall_opacity.dart';
import '../bravais_card_look.dart';
import '../bravais_card_shade.dart';
import '../bravais_current_mark.dart';
import '../bravais_item.dart';
import '../bravais_tile_motion.dart';
import 'bravais_card_layer.dart';
import 'bravais_card_motion.dart';
import 'bravais_card_surface.dart';

// Assemble original card material without a per-frame widget build. Discrete face/content changes keep this state and the independent CSS property tracks.
class BravaisCardSkin extends StatefulWidget {
  const BravaisCardSkin({
    super.key,
    required this.look,
    required this.frames,
    required this.nowMs,
    this.flight,
    this.cover,
    this.artwork = const [],
    this.badge,
    this.copy,
    this.expandedBody,
    this.marks,
    this.mosaic = false,
    this.reducedMotion = false,
    this.active = true,
    this.loading = false,
  });
  final BravaisCardLook look;
  final Listenable frames;
  final double Function() nowMs;
  final BravaisTileMotion<dynamic>? flight;
  final Widget? cover, badge, copy, marks;
  final List<Widget> artwork;
  final Widget Function(Widget glint)? expandedBody;
  final bool mosaic, reducedMotion, active, loading;
  @override
  State<BravaisCardSkin> createState() => _BravaisCardSkinState();
}

class _BravaisCardSkinState extends State<BravaisCardSkin> {
  late final BravaisCardMotion _motion;
  bool _tickerEnabled = true;
  @override
  void initState() {
    super.initState();
    _motion = BravaisCardMotion(
      look: widget.look,
      frames: widget.frames,
      nowMs: widget.nowMs,
      reducedMotion: widget.reducedMotion,
      active: false,
      loading: widget.loading,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _motion.active = widget.active && _tickerEnabled;
  }

  @override
  void didUpdateWidget(BravaisCardSkin old) {
    super.didUpdateWidget(old);
    _motion.rebind(widget.frames, widget.nowMs);
    _motion.reducedMotion = widget.reducedMotion;
    _motion.loading = widget.loading;
    _motion.active = widget.active && _tickerEnabled;
    _motion.update(widget.look);
  }

  Widget _overlay(BravaisCardPhase phase) => Positioned.fill(
    child: IgnorePointer(
      child: CustomPaint(painter: BravaisCardOverlay(_motion, phase)),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final w = widget,
        look = w.look,
        content = look.face.item != null,
        heading = look.face.kind == BravaisTileKind.heading,
        window = look.face.kind == BravaisTileKind.window,
        glint = _overlay(BravaisCardPhase.glint);
    return TickerMode(
      enabled: w.active && _tickerEnabled,
      child: BravaisCardLayer(
        motion: _motion,
        flight: w.flight,
        child: WallBoxShadows(
          shadows: _motion.shadows,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: BravaisCardPaper(look)),
                if (w.cover != null &&
                    content &&
                    !heading &&
                    !look.face.seeThrough)
                  w.cover!,
                if (content && !heading) ...[
                  ...w.artwork,
                  BravaisCardShade(
                    shade: look.palette.shade,
                    expanded: look.isExpanded,
                    mosaic: w.mosaic,
                  ),
                ],
                if (content)
                  WallOpacity(
                    opacity: _motion.signal(BravaisCardPhase.copy),
                    child: RepaintBoundary(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (w.badge != null) w.badge!,
                          if (w.copy != null && w.expandedBody == null) w.copy!,
                        ],
                      ),
                    ),
                  ),
                if (!window && w.expandedBody == null) glint,
                if (w.expandedBody != null) w.expandedBody!(glint),
                if (content && !heading && !look.face.seeThrough)
                  _overlay(BravaisCardPhase.tint),
                if (w.marks != null && content && !heading) w.marks!,
                if (look.current)
                  BravaisCurrentMark(
                    accent: look.palette.accent,
                    shade: look.palette.shade,
                    shadows: _motion.currentShadows,
                    focusStrength: _motion.signal(
                      BravaisCardPhase.currentFocus,
                    ),
                  ),
                if (content && !heading) _overlay(BravaisCardPhase.dim),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }
}
