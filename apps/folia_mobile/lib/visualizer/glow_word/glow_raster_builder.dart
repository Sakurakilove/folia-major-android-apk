part of 'glow_word_glyphs.dart';

// Preparation owns every temporary until the complete word is transferred; failures and stale requests can dispose without leaking images.
class _GlowRasterBuilder {
  _GlowRasterBuilder(this.font, this.dpr);
  final FoliaTypography font;
  final double dpr;
  final owned = <GlowGlyphRaster>[],
      paragraphs = <TextPainter>[],
      pendingImages = <ui.Image>[];
  TextPainter paragraph(InlineSpan span) {
    final p = TextPainter(
      text: span,
      textDirection: font.direction,
      locale: font.locale,
      textScaler: TextScaler.noScaling,
    )..layout();
    paragraphs.add(p);
    return p;
  }

  Future<ui.Image> image(TextPainter p, ui.Rect rect) async {
    final recorder = ui.PictureRecorder();
    // A dedicated recorder per image makes pending images independently owned if a later decode fails.
    final target = ui.Canvas(recorder)
      ..scale(dpr)
      ..translate(-rect.left, -rect.top);
    p.paint(target, ui.Offset.zero);
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(
        (rect.width * dpr).ceil().clamp(1, 0x7fffffff),
        (rect.height * dpr).ceil().clamp(1, 0x7fffffff),
      );
      pendingImages.add(image);
      return image;
    } finally {
      picture.dispose();
    }
  }

  Future<GlowGlyphRaster> raster(
    TextPainter white,
    ui.Rect rect,
    InlineSpan Function(ui.Color) textForColor, {
    bool mask = true,
  }) async {
    final a = mask ? await image(white, rect) : null;
    final actualRect = a == null
        ? rect
        : ui.Rect.fromLTWH(rect.left, rect.top, a.width / dpr, a.height / dpr);
    final resolvedFont = font;
    final result = GlowGlyphRaster(
      a,
      actualRect,
      (color) => TextPainter(
        text: textForColor(color),
        textDirection: resolvedFont.direction,
        locale: resolvedFont.locale,
        textScaler: TextScaler.noScaling,
      )..layout(),
    );
    owned.add(result);
    pendingImages.remove(a);
    return result;
  }

  void dispose() {
    for (final p in paragraphs) {
      p.dispose();
    }
    for (final r in owned) {
      r.dispose();
    }
    for (final i in pendingImages) {
      i.dispose();
    }
    paragraphs.clear();
    owned.clear();
    pendingImages.clear();
  }
}
