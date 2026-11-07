import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../wall/wall_css_paint.dart';
import '../bravais_card_look.dart';
import '../bravais_item.dart';
import 'bravais_card_motion.dart';

class BravaisCoverFallback extends CustomPainter {
  BravaisCoverFallback(String key) : colors = wallFallbackColors(key);
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = wallLinearGradient(rect, 145, colors),
    );
  }

  @override
  bool shouldRepaint(BravaisCoverFallback old) =>
      old.colors[0] != colors[0] || old.colors[1] != colors[1];
}

// Native paint layers follow the original CSS stacking order, including the empty frame and the transparent window's elliptical glow.
class BravaisCardPaper extends CustomPainter {
  const BravaisCardPaper(this.look);
  final BravaisCardLook look;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size, p = look.palette;
    if (look.face.kind == BravaisTileKind.wall) {
      return; // Its inset frame belongs to the independently transitioning box-shadow list.
    } else if (look.face.kind == BravaisTileKind.window ||
        look.face.seeThrough) {
      // CSS radial-gradient(ellipse at 50% 40%, accent 9%, transparent 70%): farthest-corner scales the ellipse by sqrt(2).
      final rx = size.width * .5 * math.sqrt2,
          ry = size.height * .6 * math.sqrt2;
      if (rx <= 0 || ry <= 0) return;
      final matrix = Matrix4.identity()..scaleByDouble(1, ry / rx, 1, 1);
      final center = Offset(size.width * .5, size.height * .4);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.drawRect(
        rect.shift(-center),
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            rx,
            [
              p.accent.withValues(alpha: p.accent.a * .09),
              const Color(0x00000000),
            ],
            [0, .7],
            TileMode.clamp,
            matrix.storage,
          ),
      );
      canvas.restore();
    } else {
      canvas.drawRect(rect, Paint()..color = p.posterBackground);
    }
  }

  @override
  bool shouldRepaint(BravaisCardPaper old) => old.look != look;
}

class BravaisCardOverlay extends CustomPainter {
  BravaisCardOverlay(this.motion, this.phase) : super(repaint: motion);
  final BravaisCardMotion motion;
  final BravaisCardPhase phase;
  @override
  void paint(Canvas canvas, Size size) {
    final alpha = motion.value(phase);
    if (alpha <= 0) return;
    final p = motion.look.palette, rect = Offset.zero & size;
    if (phase == BravaisCardPhase.dim) {
      canvas.drawRect(rect, Paint()..color = p.shade.withValues(alpha: alpha));
    } else {
      final glint = phase == BravaisCardPhase.glint;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = wallLinearGradient(
            rect,
            glint ? 180 : 145,
            glint
                ? [
                    Color.from(alpha: .1 * alpha, red: 1, green: 1, blue: 1),
                    const Color(0x00000000),
                  ]
                : p.tintColors
                      .map((c) => c.withValues(alpha: c.a * alpha))
                      .toList(growable: false),
            stops: glint ? [0, .6] : null,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(BravaisCardOverlay old) =>
      old.motion != motion || old.phase != phase;
}
