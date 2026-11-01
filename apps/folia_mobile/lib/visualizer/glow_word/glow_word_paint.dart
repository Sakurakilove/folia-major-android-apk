import 'dart:math' as math;
import 'dart:ui' as ui;

import '../motion/color_value.dart';
import 'glow_glyph_motion.dart';
import 'glow_word_glyphs.dart';
import 'glow_word_motion.dart';

part 'glow_word_paint_effects.dart';

// Render the original stacking order from prepared inputs: grapheme halos, chorus ripple, then the readable body.
class GlowWordPaint {
  final _group = ui.Paint(),
      _image = ui.Paint(),
      _shadow = ui.Paint(),
      _glyph = ui.Paint(),
      _ripple = ui.Paint();
  static ui.Color _color(MotionRgba c, [double? alpha]) => ui.Color.fromRGBO(
    c.red.round().clamp(0, 255),
    c.green.round().clamp(0, 255),
    c.blue.round().clamp(0, 255),
    (alpha ?? c.alpha).clamp(0.0, 1.0),
  );

  void paint(
    ui.Canvas canvas,
    GlowWordMotion motion,
    GlowWordGlyphs glyphs, [
    ui.Offset origin = ui.Offset.zero,
    ui.Size? boxSize,
  ]) {
    final layout = motion.layout,
        alpha = layout['opacity']!.value.clamp(0.0, 1.0);
    if (alpha <= 0) return;
    final box = boxSize ?? glyphs.size, center = box.center(ui.Offset.zero);
    canvas.save();
    canvas.translate(
      origin.dx + center.dx + layout['x']!.value,
      origin.dy + center.dy + layout['y']!.value,
    );
    canvas.rotate(layout['rotate']!.value * math.pi / 180);
    canvas.scale(layout['scale']!.value);
    canvas.translate(-center.dx, -center.dy);
    var bounds = glyphs.body.rect.inflate(160);
    for (final raster in glyphs.glow) {
      if (raster != null) {
        bounds = bounds.expandToInclude(raster.rect.inflate(160));
      }
    }
    final rippleDiameter = box.height * 1.5 * math.max(1.0, motion.rippleScale);
    bounds = bounds.expandToInclude(
      ui.Rect.fromCircle(center: center, radius: rippleDiameter / 2 + 8),
    );
    if (alpha < 1) {
      canvas.saveLayer(
        bounds,
        _group..color = ui.Color.fromRGBO(255, 255, 255, alpha),
      );
    }
    for (var i = 0; i < glyphs.glow.length; i++) {
      final raster = glyphs.glow[i];
      if (raster == null) continue;
      final glow = motion.glyphs[i];
      if (glow.dropShadow) {
        _dropShadow(canvas, raster, glow);
      } else if (glow.shadowAlpha > 0) {
        final color = _color(glow.color, glow.shadowAlpha);
        // CSS paints the first listed shadow over the second, and its radius means twice sigma.
        _halo(canvas, raster, color, math.max(0, glow.outerRadius) / 2);
        _halo(canvas, raster, color, math.max(0, glow.innerRadius) / 2);
      }
    }
    _ripples(canvas, motion, center, box.height);
    _drawGlyph(
      canvas,
      glyphs.body,
      motion.bodyColor.value,
      math.max(0, motion.bodyBlur.value),
    );
    if (alpha < 1) canvas.restore();
    canvas.restore();
  }

  void _drawGlyph(
    ui.Canvas canvas,
    GlowGlyphRaster raster,
    MotionRgba color, [
    double blur = 0,
  ]) {
    if (blur > 0) {
      canvas.saveLayer(
        raster.rect.inflate(blur * 4 + 4),
        _glyph..imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      );
    }
    raster.paintColor(canvas, _color(color));
    if (blur > 0) canvas.restore();
  }

  void _halo(
    ui.Canvas canvas,
    GlowGlyphRaster raster,
    ui.Color color,
    double sigma,
  ) {
    _shadow
      ..colorFilter = ui.ColorFilter.mode(color, ui.BlendMode.srcIn)
      ..imageFilter = sigma <= 0
          ? null
          : ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    canvas.drawImageRect(
      raster.image!,
      ui.Rect.fromLTWH(
        0,
        0,
        raster.image!.width.toDouble(),
        raster.image!.height.toDouble(),
      ),
      raster.rect,
      _shadow,
    );
  }
}
