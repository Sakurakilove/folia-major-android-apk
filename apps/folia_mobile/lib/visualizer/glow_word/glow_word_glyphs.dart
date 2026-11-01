import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../rendering/css_text.dart';
import '../../rendering/folia_typography.dart';
import 'glow_word_motion.dart';

part 'glow_word_rasterize.dart';
part 'glow_raster_builder.dart';

// Prepared native paragraphs retain color-font and coverage behavior; only halo inputs are rasterized at full DPR.
class GlowGlyphRaster {
  GlowGlyphRaster(this.image, this.rect, this._paragraphForColor);
  final ui.Image? image;
  final ui.Rect rect;
  final TextPainter Function(ui.Color) _paragraphForColor;
  TextPainter? _paragraph;
  ui.Color? _color;
  int get bytes => image == null ? 0 : image!.width * image!.height * 4;
  // Color-dependent glyph AA and overlaps cannot be reproduced by tinting one opaque mask.
  void paintColor(ui.Canvas canvas, ui.Color color) {
    if (_color != color) {
      _paragraph?.dispose();
      _paragraph = _paragraphForColor(color);
      _color = color;
    }
    _paragraph!.paint(canvas, ui.Offset.zero);
  }

  void dispose() {
    _paragraph?.dispose();
    image?.dispose();
  }
}

class GlowWordGlyphs {
  GlowWordGlyphs._(this.body, this.glow, this.size, this.dpr, this.fontKey);
  final GlowGlyphRaster body;
  final List<GlowGlyphRaster?> glow;
  final ui.Size size;
  final double dpr;
  final String fontKey;
  int get bytes => body.bytes + glow.fold(0, (n, g) => n + (g?.bytes ?? 0));
  bool _closed = false;
  void dispose() {
    if (_closed) return;
    _closed = true;
    body.dispose();
    for (final glyph in glow) {
      glyph?.dispose();
    }
  }

  static Future<GlowWordGlyphs> prepare(
    GlowWordMotion motion,
    FoliaTypography typography,
    double fontPx,
    double dpr,
  ) => _rasterize(motion, typography.withHeight(1.22), fontPx, dpr);
}

// Collapse as one CSS inline flow, preserving which original span owns a surviving space.
List<String> _normalRuns(List<String> source) {
  final runs = List.generate(source.length, (_) => StringBuffer());
  int? pending;
  var started = false;
  for (var i = 0; i < source.length; i++) {
    for (final codepoint in source[i].runes) {
      if (codepoint == 9 ||
          codepoint == 10 ||
          codepoint == 13 ||
          codepoint == 12 ||
          codepoint == 32) {
        pending ??= i;
      } else {
        if (pending != null && started) runs[pending].write(' ');
        pending = null;
        runs[i].writeCharCode(codepoint);
        started = true;
      }
    }
  }
  return runs.map((s) => s.toString()).toList(growable: false);
}
