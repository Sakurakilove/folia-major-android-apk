part of 'monet_rail_painter.dart';

// Masks rendering is cached or bounded to the visible rail.
extension _MonetRailMasks on MonetRailPainter {
  void _chorus(
    Canvas canvas,
    double width,
    double height,
    double opacity,
    double scale,
  ) {
    if (opacity <= 0 || width <= 0 || height <= 0) return;
    final bounds = Rect.fromLTWH(-30, -30, width + 60, height + 60);
    if (_chorusOpacity != opacity) {
      _chorusLayer.color = Color.fromRGBO(255, 255, 255, opacity);
      _chorusOpacity = opacity;
    }
    canvas.saveLayer(bounds, _chorusLayer);
    canvas.save();
    canvas.translate(width / 2, height / 2);
    canvas.scale(scale);
    canvas.translate(-width / 2, -height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        const Radius.circular(16),
      ),
      _chorusFills.putIfAbsent(
        (width, height),
        () => Paint()
          ..shader = ui.Gradient.radial(
            Offset(width * .5, height * .45),
            math.sqrt(math.pow(width * .5, 2) + math.pow(height * .55, 2)),
            [
              accent.withValues(alpha: .14),
              accent.withValues(alpha: .04),
              accent.withValues(alpha: 0),
            ],
            [0, .55, .82],
          ),
      ),
    );
    canvas.restore();
    canvas.restore();
  }

  void _verticalMask(Canvas canvas, Rect bounds, double solidEnd, double end) =>
      canvas.drawRect(
        bounds,
        _fadePaints.putIfAbsent(
          (false, solidEnd, end),
          () => Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = ui.Gradient.linear(
              Offset(0, solidEnd),
              Offset(0, math.max(end, solidEnd + .001)),
              const [Color(0xffffffff), Color(0x00ffffff)],
            ),
        ),
      );
  void _horizontalMask(
    Canvas canvas,
    Rect bounds,
    double solidEnd,
    double end,
  ) => canvas.drawRect(
    bounds,
    _fadePaints.putIfAbsent(
      (true, solidEnd, end),
      () => Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          Offset(solidEnd, 0),
          Offset(end, 0),
          const [Color(0xffffffff), Color(0x00ffffff)],
        ),
    ),
  );
}
