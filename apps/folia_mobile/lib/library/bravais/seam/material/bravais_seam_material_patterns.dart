part of 'bravais_seam_material_painter.dart';

// Preserve the original absolute lengths, stop fixup and source Bayer dithering. Each layer remains a separate source-over draw.
extension _BravaisSeamMaterialPatterns on BravaisSeamMaterialPainter {
  void _createPatterns(Size size) {
    final p = look.palette, w = size.width, h = size.height;
    Color alpha(Color color, double amount) =>
        color.withValues(alpha: color.a * amount);
    ui.FragmentShader createPattern(
      double kind,
      Offset from,
      Offset to,
      Color color,
      double edge, {
      bool transient = false,
    }) {
      final ui.FragmentShader shader;
      if (transient) {
        shader = program.createPattern();
      } else {
        if (_fragmentIndex >= _fragments.length) {
          _fragments.add(program.createPattern());
        }
        shader = _fragments[_fragmentIndex++];
      }
      shader
        ..setFloat(0, kind)
        ..setFloat(1, from.dx)
        ..setFloat(2, from.dy)
        ..setFloat(3, to.dx)
        ..setFloat(4, to.dy)
        ..setFloat(5, color.r)
        ..setFloat(6, color.g)
        ..setFloat(7, color.b)
        ..setFloat(8, color.a)
        ..setFloat(9, edge)
        ..setFloat(10, 0)
        ..setFloat(11, dpr)
        ..setFloat(12, 0);
      return shader;
    }

    void pattern(
      double kind,
      Offset from,
      Offset to,
      Color color,
      double edge,
    ) => _add(createPattern(kind, from, to, color, edge));
    void bands(Offset from, Offset to, Color color, double end) =>
        pattern(0, from, to, color, end);
    void tile(
      String key,
      double extent,
      Color color,
      bool vertical,
      double edge,
    ) {
      final image = _tiles.putIfAbsent(key, () {
        final pixels = (extent * dpr).ceil(),
            shader = createPattern(
              0,
              Offset.zero,
              vertical ? Offset(0, extent) : Offset(extent, 0),
              color,
              edge,
              transient: true,
            );
        shader
          ..setFloat(11, pixels / extent)
          ..setFloat(12, 1);
        final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
        canvas.scale(pixels / extent, pixels / extent);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, extent, extent),
          Paint()..shader = shader,
        );
        final picture = recorder.endRecording(),
            image = picture.toImageSync(pixels, pixels);
        picture.dispose();
        program.releaseShader(shader);
        return image;
      });
      _add(
        ui.ImageShader(
          image,
          TileMode.repeated,
          TileMode.repeated,
          (Matrix4.identity()
                ..translateByDouble(w / 2 - extent / 2, 0, 0, 1)
                ..scaleByDouble(
                  extent / image.width,
                  extent / image.height,
                  1,
                  1,
                ))
              .storage,
          filterQuality: FilterQuality.low,
        ),
      );
    }

    if (look.clear) {
      pattern(3, Offset(0, h * .22), Offset.zero, alpha(p.ink, .06), 0);
      return;
    }
    switch (look.effectiveStyle) {
      case BravaisSeamStyle.white:
      case BravaisSeamStyle.black:
        pattern(
          2,
          Offset(w, 0),
          Offset.zero,
          alpha(
            look.ink,
            look.effectiveStyle == BravaisSeamStyle.white ? .22 : .24,
          ),
          0,
        );
      case BravaisSeamStyle.hatch:
        final radians = 135 * math.pi / 180,
            dx = math.sin(radians),
            dy = -math.cos(radians),
            length = w * dx.abs() + h * dy.abs(),
            from = Offset(w / 2 - dx * length / 2, h / 2 - dy * length / 2);
        bands(from, from + Offset(dx * 7, dy * 7), alpha(p.accent, .14), 1 / 7);
      case BravaisSeamStyle.contour:
        pattern(
          1,
          Offset(w / 2 + 170, h * .82),
          const Offset(22, 330 / 240),
          alpha(p.secondary, .14),
          21 / 22,
        );
        pattern(
          1,
          Offset(w / 2 - 150, h * .24),
          const Offset(16, 190 / 300),
          alpha(p.ink, .1),
          15 / 16,
        );
      case BravaisSeamStyle.check:
        tile('fine', 56, alpha(p.secondary, .1), false, 1 / 56);
        tile('horizontal', 14, alpha(p.accent, .07), true, .5);
        tile('vertical', 14, alpha(p.accent, .07), false, .5);
      default:
        break;
    }
  }
}
