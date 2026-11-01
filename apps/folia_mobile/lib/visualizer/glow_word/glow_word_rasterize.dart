part of 'glow_word_glyphs.dart';

// Prepare body and original per-grapheme inline spans off the frame path, retaining contextual shaping and source UTF-16 boundaries.
Future<GlowWordGlyphs> _rasterize(
  GlowWordMotion motion,
  FoliaTypography font,
  double px,
  double dpr,
) async {
  if (!dpr.isFinite || dpr <= 0 || !px.isFinite || px <= 0) {
    throw ArgumentError(
      'Glyph rasterization requires positive font size and DPR',
    );
  }
  final builder = _GlowRasterBuilder(font, dpr);
  final paragraph = builder.paragraph, raster = builder.raster;
  try {
    final bodyText = cssNormalText(motion.word.text), style = font.style(px);
    final bodyParagraph = paragraph(TextSpan(text: bodyText, style: style));
    final size = bodyText.isEmpty ? ui.Size.zero : bodyParagraph.size;
    final padding = px;
    final body = await raster(
      bodyParagraph,
      (ui.Offset.zero & size).inflate(padding),
      (color) => TextSpan(
        text: bodyText,
        style: font.style(px, color: color),
      ),
      mask: false,
    );
    final sourceRuns = motion.graphemes.length > 1
        ? motion.graphemes.map((g) => g.char).toList()
        : [motion.word.text];
    final runs = _normalRuns(sourceRuns), text = runs.join();
    final full = paragraph(TextSpan(text: text, style: style));
    final glow = <GlowGlyphRaster?>[];
    var cursor = 0;
    for (var i = 0; i < runs.length; i++) {
      final end = cursor + runs[i].length;
      final boxes = full.getBoxesForSelection(
        TextSelection(baseOffset: cursor, extentOffset: end),
      );
      cursor = end;
      if (runs[i].isEmpty || boxes.isEmpty) {
        glow.add(null);
        continue;
      }
      var bounds = boxes.first.toRect();
      for (final box in boxes.skip(1)) {
        bounds = bounds.expandToInclude(box.toRect());
      }
      final p = paragraph(
        TextSpan(
          style: style,
          children: [
            for (var j = 0; j < runs.length; j++)
              TextSpan(
                text: runs[j],
                style: TextStyle(
                  color: ui.Color(j == i ? 0xffffffff : 0x00ffffff),
                ),
              ),
          ],
        ),
      );
      glow.add(
        await raster(
          p,
          bounds.inflate(padding),
          (color) => TextSpan(
            style: style,
            children: [
              for (var j = 0; j < runs.length; j++)
                TextSpan(
                  text: runs[j],
                  style: TextStyle(
                    color: j == i ? color : const ui.Color(0x00ffffff),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    final result = GlowWordGlyphs._(
      body,
      List.unmodifiable(glow),
      size,
      dpr,
      '$px|${font.cacheKey}|$dpr',
    );
    builder.owned.clear();
    return result;
  } finally {
    builder.dispose();
  }
}
