part of 'bravais_poster_button.dart';

// Preserve square borders, outside-only hard shadow and the source 2px focus outline at 4px offset. Hover is immediate CSS here; this control owns no display clock.
class RenderBravaisPosterButton extends RenderProxyBox {
  RenderBravaisPosterButton(this._style, this._focused);
  BravaisPosterButtonStyle _style;
  bool _focused;
  final _fill = Paint(),
      _border = Paint(),
      _shadow = Paint(),
      _outline = Paint()
        ..color = const Color(0xffffffff)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
  void update(BravaisPosterButtonStyle style, bool focused) {
    _style = style;
    _focused = focused;
    markNeedsPaint();
  }

  @override
  Rect get paintBounds {
    if (!hasSize) return Rect.zero;
    final bounds = Offset.zero & size;
    return _focused
        ? bounds.inflate(6)
        : _style.shadow.a > 0
        ? bounds.expandToInclude(bounds.shift(const Offset(5, 5)))
        : bounds;
  }

  void _base(Canvas canvas, Rect bounds) {
    if (_style.shadow.a > 0) {
      canvas.save();
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(paintBounds.shift(bounds.topLeft).inflate(1))
          ..addRect(bounds),
      );
      canvas.drawRect(
        bounds.shift(const Offset(5, 5)),
        _shadow..color = _style.shadow,
      );
      canvas.restore();
    }
    canvas.drawRect(bounds, _fill..color = _style.background);
    canvas.drawDRRect(
      RRect.fromRectAndRadius(bounds, Radius.zero),
      RRect.fromRectAndRadius(bounds.deflate(_style.borderWidth), Radius.zero),
      _border..color = _style.border,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final bounds = offset & size;
    _base(context.canvas, bounds);
    super.paint(context, offset);
    if (_focused) context.canvas.drawRect(bounds.inflate(5), _outline);
  }
}
