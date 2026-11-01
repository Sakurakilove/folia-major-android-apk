import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'monet_rail_motion.dart';
import 'monet_text_measurement.dart';
import '../glyph_cache.dart';
import '../../rendering/folia_typography.dart';

// Prepared paint ownership is separate from widget state and the per-frame renderer.
class MonetPaintRun {
  MonetPaintRun(
    this.run,
    this.cacheKey,
    this.wordColor,
    ui.FragmentShader shader,
  ) : shader = shader,
      paint = ui.Paint()..shader = shader;
  final MonetTextRun run;
  final String cacheKey;
  final Color wordColor;
  final ui.FragmentShader shader;
  final ui.Paint paint;
  GlyphRaster? boundRaster;
  bool? lastPassed;
  double? lastFill, lastProgress, lastGlow;
  void dispose() => shader.dispose();
}

class MonetPaintRow {
  MonetPaintRow(
    this.motion,
    this.runs,
    this.subtitles,
    this.staticParagraph,
    this.flow,
    this.typography,
    this.staticTokens,
  );
  final MonetRailMotion motion;
  final List<MonetPaintRun> runs;
  final List<TextPainter> subtitles;
  late final _subtitleLayers = List.generate(
    subtitles.length,
    (_) => ui.Paint(),
  );
  late final _subtitleOpacities = List<double?>.filled(subtitles.length, null);
  final TextPainter? staticParagraph;
  final MonetTextFlow flow;
  final FoliaTypography typography;
  final TextPainter? staticTokens;
  final ui.Paint layerPaint = ui.Paint();
  bool ready = false;
  double? _opacity, _blur;
  late final double renderEndTime = motion.entry.entry.line.hints.renderEndTime;
  ui.Paint updateLayer(double opacity, double blur) {
    if (_opacity != opacity) {
      layerPaint.color = ui.Color.fromRGBO(255, 255, 255, opacity);
      _opacity = opacity;
    }
    if (_blur != blur) {
      layerPaint.imageFilter = blur > 0
          ? ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur)
          : null;
      _blur = blur;
    }
    return layerPaint;
  }

  ui.Paint subtitleLayer(int index, double opacity) {
    if (_subtitleOpacities[index] != opacity) {
      _subtitleLayers[index].color = ui.Color.fromRGBO(255, 255, 255, opacity);
      _subtitleOpacities[index] = opacity;
    }
    return _subtitleLayers[index];
  }

  void dispose() {
    for (final run in runs) {
      run.dispose();
    }
    for (final text in subtitles) {
      text.dispose();
    }
    staticParagraph?.dispose();
    staticTokens?.dispose();
  }
}
