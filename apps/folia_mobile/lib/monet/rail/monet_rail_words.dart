part of 'monet_rail_painter.dart';

// Words rendering is cached or bounded to the visible rail.
extension _MonetRailWords on MonetRailPainter {
  void _word(
    Canvas canvas,
    MonetPaintRow row,
    MonetPaintRun run,
    double time,
    double top,
  ) {
    final glyph = cache.peek(run.cacheKey);
    if (glyph == null) return;
    final token = run.run.token, status = row.motion.entry.entry.status;
    final active = token.timed && status == 'active';
    final passed =
        token.timed && (status == 'passed' || active && time > token.end!);
    final glow = token.timed && (status == 'active' || status == 'passed')
        ? resolveMonetGlow(time, token.start!, token.end!, row.renderEndTime)
        : 0.0;
    final fill = active
        ? resolveMonetFillWidth(
            time,
            token.start!,
            token.end!,
            glyph.offsets,
            token.graphemeTimings,
          )
        : 0.0;
    final progress = active
        ? time <= token.start!
              ? 0.0
              : time >= token.end!
              ? 1.0
              : (time - token.start!) /
                    math.max(.001, token.end! - token.start!)
        : 0.0;
    final shader = run.shader;
    // Static uniforms/samplers bind once; only changing local floats touch the shader buffer per frame.
    if (!identical(run.boundRaster, glyph)) {
      run.boundRaster = glyph;
      run.lastPassed = null;
      run.lastFill = null;
      run.lastProgress = null;
      run.lastGlow = null;
      shader.setFloat(0, glyph.size.width);
      shader.setFloat(1, glyph.size.height);
      shader.setFloat(2, glyph.padding);
      shader.setFloat(3, glyph.advance);
      shader.setFloat(6, active ? 1 : 0);
      shader.setFloat(8, row.motion.entry.entry.line.isChorus ? 1 : .88);
      shader.setFloat(9, primary.r);
      shader.setFloat(10, primary.g);
      shader.setFloat(11, primary.b);
      shader.setFloat(12, row.motion.entry.tone.baseAlpha);
      shader.setFloat(17, run.wordColor.r);
      shader.setFloat(18, run.wordColor.g);
      shader.setFloat(19, run.wordColor.b);
      shader.setFloat(20, run.wordColor.a);
      shader.setFloat(21, resolveMonetSweepEdgeSoftness(fontPx));
      shader.setImageSampler(0, glyph.glyph);
      shader.setImageSampler(1, glyph.nearGlow);
      shader.setImageSampler(2, glyph.farGlow);
    }
    if (run.lastPassed != passed) {
      final color = passed ? run.wordColor : primary;
      shader.setFloat(13, color.r);
      shader.setFloat(14, color.g);
      shader.setFloat(15, color.b);
      shader.setFloat(
        16,
        passed ? run.wordColor.a : row.motion.entry.tone.baseAlpha,
      );
      run.lastPassed = passed;
    }
    if (run.lastFill != fill) {
      shader.setFloat(4, fill);
      run.lastFill = fill;
    }
    if (run.lastProgress != progress) {
      shader.setFloat(5, progress);
      run.lastProgress = progress;
    }
    if (run.lastGlow != glow) {
      shader.setFloat(7, glow);
      run.lastGlow = glow;
    }
    canvas.save();
    canvas.translate(
      run.run.offset.dx - glyph.padding,
      top + run.run.offset.dy - glyph.padding,
    );
    if (!token.timed && status == 'active' && glyph.backgroundShadow != null) {
      final image = glyph.backgroundShadow!;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 14, glyph.size.width, glyph.size.height),
        _staticShadowPaint,
      );
    }
    canvas.drawRect(Offset.zero & glyph.size, run.paint);
    canvas.restore();
  }
}
