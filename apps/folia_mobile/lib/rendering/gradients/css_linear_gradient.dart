part of 'css_gradient_program.dart';

// Geometry and color transforms change only with their input, while animated opacity updates one native uniform. No per-frame image, texture or widget copy is needed.
class CssLinearGradientEffect {
  CssLinearGradientEffect._(this._owner, this.shader)
    : _paint = ui.Paint()..shader = shader;
  final CssGradientProgram _owner;
  final ui.FragmentShader shader;
  final ui.Paint _paint;
  ui.Color? _first, _last;
  (double, double, double)? _geometry;
  double? _opacity;
  (bool, double)? _dither;
  bool _closed = false;
  void paint(
    ui.Canvas canvas,
    ui.Rect bounds,
    double degrees,
    List<ui.Color> colors, {
    double opacity = 1,
    bool dither = false,
    double dpr = 1,
  }) {
    if (_closed || bounds.isEmpty || opacity <= 0) return;
    assert(colors.length == 2);
    final first = colors.first,
        last = colors.last,
        geometry = (bounds.width, bounds.height, degrees);
    if (_geometry != geometry) {
      _geometry = geometry;
      final radians = degrees * math.pi / 180,
          dx = math.sin(radians),
          dy = -math.cos(radians),
          length = bounds.width * dx.abs() + bounds.height * dy.abs(),
          hx = dx * length / 2,
          hy = dy * length / 2,
          cx = bounds.width / 2,
          cy = bounds.height / 2;
      shader
        ..setFloat(0, cx - hx)
        ..setFloat(1, cy - hy)
        ..setFloat(2, cx + hx)
        ..setFloat(3, cy + hy);
    }
    void color(ui.Color value, int offset) {
      final lab = CssOklab.fromColor(value);
      shader
        ..setFloat(offset, lab.l)
        ..setFloat(offset + 1, lab.a)
        ..setFloat(offset + 2, lab.b)
        ..setFloat(offset + 3, lab.alpha);
    }

    if (_first != first) {
      _first = first;
      color(first, 4);
    }
    if (_last != last) {
      _last = last;
      color(last, 8);
    }
    if (_opacity != opacity) {
      _opacity = opacity;
      shader.setFloat(12, opacity);
    }
    if (_dither != (dither, dpr)) {
      _dither = (dither, dpr);
      shader
        ..setFloat(31, dither ? 1 : 0)
        ..setFloat(32, dpr);
    }
    canvas.save();
    canvas.translate(bounds.left, bounds.top);
    canvas.drawRect(ui.Offset.zero & bounds.size, _paint);
    canvas.restore();
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _owner._release(shader);
  }
}
