import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../wall/wall_box_shadows.dart';
import '../../wall/wall_css_paint.dart';
import '../tiles/bravais_card_palette.dart';

// Default theme paper and the mutually exclusive clear-seam veil. Print/frost/pattern/poster surfaces are separate source materials, not silently replaced with this paper.
class BravaisSeamPaper extends CustomPainter {
  BravaisSeamPaper({
    required BravaisCardPalette palette,
    bool seeThrough = false,
    this.clear = false,
    bool backdropBlur = false,
    Color? customPaper,
    this.paintClearEdge = true,
    this.includeInsetShadows = true,
  }) : paper = clear
           ? palette.background.withValues(
               alpha: palette.background.a * (backdropBlur ? .5 : .64),
             )
           : customPaper ??
                 wallSrgbMix(palette.background, palette.ink, .1).withValues(
                   alpha:
                       wallSrgbMix(palette.background, palette.ink, .1).a *
                       (seeThrough ? .8 : 1),
                 ),
       edge = palette.ink.withValues(alpha: palette.ink.a * .06),
       shadows = [
         if (clear) ...[
           WallBoxShadow(
             palette.ink.withValues(alpha: palette.ink.a * .12),
             offset: const Offset(1, 0),
             inset: true,
           ),
           WallBoxShadow(
             palette.ink.withValues(alpha: palette.ink.a * .12),
             offset: const Offset(-1, 0),
             inset: true,
           ),
         ],
         WallBoxShadow(
           palette.ink.withValues(
             alpha: palette.ink.a * (palette.daylight ? .08 : .06),
           ),
           spread: 1,
         ),
         WallBoxShadow(
           (palette.daylight
                   ? const Color(0xff2a231b)
                   : const Color(0xff000000))
               .withValues(alpha: palette.daylight ? .18 : .42),
           offset: const Offset(0, 24),
           blur: 64,
         ),
       ];
  final Color paper, edge;
  final bool clear, paintClearEdge, includeInsetShadows;
  final List<WallBoxShadow> shadows;
  final _fill = Paint(), _edge = Paint();
  Size? _size;
  Path? _shadowClip;
  Shader? _edgeGradient;
  void _prepare(Size size) {
    if (_size == size) return;
    _size = size;
    final bounds = Offset.zero & size;
    _shadowClip = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(bounds.inflate(122))
      ..addRect(bounds);
    _edge.shader = null;
    _edgeGradient?.dispose();
    _edgeGradient = clear && paintClearEdge
        ? wallLinearGradient(
            bounds,
            180,
            [edge, edge.withAlpha(0)],
            stops: [0, .22],
          )
        : null;
    _edge.shader = _edgeGradient;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _prepare(size);
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipPath(_shadowClip!);
    for (final shadow in shadows.reversed) {
      if (!shadow.inset) shadow.paint(canvas, bounds);
    }
    canvas.restore();
    canvas.drawRect(bounds, _fill..color = paper);
    final edgeGradient = _edgeGradient;
    if (edgeGradient != null) {
      canvas.drawRect(bounds, _edge);
    }
    if (includeInsetShadows) paintInsets(canvas, size);
  }

  void paintInsets(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    for (final shadow in shadows.reversed) {
      if (shadow.inset) shadow.paint(canvas, bounds);
    }
  }

  @override
  bool shouldRepaint(BravaisSeamPaper oldDelegate) =>
      paper != oldDelegate.paper ||
      edge != oldDelegate.edge ||
      clear != oldDelegate.clear ||
      paintClearEdge != oldDelegate.paintClearEdge ||
      includeInsetShadows != oldDelegate.includeInsetShadows ||
      !listEquals(shadows, oldDelegate.shadows);

  void dispose() {
    _edge.shader = null;
    _edgeGradient?.dispose();
    _edgeGradient = null;
    _size = null;
    _shadowClip = null;
  }
}
