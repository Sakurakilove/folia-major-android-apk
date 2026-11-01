part of 'glow_word_paint.dart';

// Original chained filter and local chorus overlay painting share the prepared word inputs.
extension _GlowWordEffects on GlowWordPaint {
  void _dropShadow(
    ui.Canvas canvas,
    GlowGlyphRaster raster,
    GlowGlyphMotion glow,
  ) {
    final alpha = glow.opacity.value.clamp(0.0, 1.0);
    if (alpha <= 0) return;
    final inner = math.max(0.0, glow.innerRadius),
        outer = math.max(0.0, glow.outerRadius),
        bounds = raster.rect.inflate((inner + outer) * 4 + 4);
    // Chaining matters: the outer shadow also shadows the inner halo. Two independent blurs would change the original light.
    void innerAndGlyph() {
      _halo(
        canvas,
        raster,
        GlowWordPaint._color(glow.color, .7 * glow.color.alpha),
        inner,
      );
      _drawGlyph(canvas, raster, glow.color);
    }

    canvas.saveLayer(
      bounds,
      _group..color = ui.Color.fromRGBO(255, 255, 255, alpha),
    );
    _image
      ..colorFilter = ui.ColorFilter.mode(
        GlowWordPaint._color(glow.color),
        ui.BlendMode.srcIn,
      )
      ..imageFilter = outer == 0
          ? null
          : ui.ImageFilter.blur(sigmaX: outer, sigmaY: outer);
    canvas.saveLayer(bounds, _image);
    innerAndGlyph();
    canvas.restore();
    innerAndGlyph();
    canvas.restore();
  }

  void _ripples(
    ui.Canvas canvas,
    GlowWordMotion motion,
    ui.Offset center,
    double height,
  ) {
    for (final ripple in motion.ripples) {
      final alpha = ripple.opacity.value.clamp(0.0, 1.0);
      if (alpha <= 0) continue;
      final scale = ripple.scale.value;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(scale);
      // Border is inside the CSS box; transform scales the 1px border and its 1px filter together.
      _ripple
        ..color = GlowWordPaint._color(
          motion.activeColor,
          motion.activeColor.alpha * alpha,
        )
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
      canvas.drawCircle(
        ui.Offset.zero,
        math.max(0, height * 1.5 / 2 - .5),
        _ripple,
      );
      canvas.restore();
    }
  }
}
