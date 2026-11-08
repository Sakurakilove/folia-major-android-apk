part of 'bravais_album_ground_program.dart';

// Source gradients rasterize as small repeat tiles before bilinear sampling. Paper starts at -100cqh; its dots and the lower masked dots each keep their own top-left origin.
extension _AlbumGroundPatterns on BravaisAlbumGroundPainter {
  void _configureDots(
    ui.FragmentShader shader,
    double extent,
    double inner,
    double outer,
    Color color,
    double alpha,
  ) {
    shader
      ..setFloat(0, extent)
      ..setFloat(1, inner)
      ..setFloat(2, outer)
      ..setFloat(3, color.r)
      ..setFloat(4, color.g)
      ..setFloat(5, color.b)
      ..setFloat(6, color.a * alpha)
      ..setFloat(7, (extent * dpr).ceil() / extent);
  }

  ui.ImageShader _dotTile(ui.FragmentShader shader, double extent) {
    final pixels = (extent * dpr).ceil(),
        recorder = ui.PictureRecorder(),
        canvas = Canvas(recorder);
    canvas.scale(pixels / extent, pixels / extent);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, extent, extent),
      Paint()..shader = shader,
    );
    final picture = recorder.endRecording(),
        image = picture.toImageSync(pixels, pixels);
    picture.dispose();
    _tileImages.add(image);
    final result = ui.ImageShader(
      image,
      TileMode.repeated,
      TileMode.repeated,
      (Matrix4.identity()
            ..scaleByDouble(extent / pixels, extent / pixels, 1, 1))
          .storage,
      filterQuality: FilterQuality.low,
    );
    _imageShaders.add(result);
    return result;
  }

  void _ensureImages() {
    if (_ready) return;
    _paperPaint.shader = _dotTile(_paperDots, 9);
    _dotsPaint.shader = _dotTile(_lowerDots, 10);
    _hatchPaint.shader = _hatch;
    _grain = SvgNoiseImageLease(
      SvgNoiseProvider(
        native: owner.noise,
        recipe: SvgNoiseRecipe.poster,
        cssExtent: 160,
        dpr: dpr,
      ),
    )..addListener(_changed);
    _ready = true;
  }

  void _prepareHatch(Size size) {
    final radians = -58 * math.pi / 180,
        dx = math.sin(radians),
        dy = -math.cos(radians),
        length = size.width * dx.abs() + size.height * dy.abs(),
        from = Offset(
          size.width / 2 - dx * length / 2,
          size.height / 2 - dy * length / 2,
        );
    _hatch
      ..setFloat(0, 0)
      ..setFloat(1, from.dx)
      ..setFloat(2, from.dy)
      ..setFloat(3, from.dx + dx * 9)
      ..setFloat(4, from.dy + dy * 9)
      ..setFloat(5, colors.ink.r)
      ..setFloat(6, colors.ink.g)
      ..setFloat(7, colors.ink.b)
      ..setFloat(8, colors.ink.a)
      ..setFloat(9, 2 / 9)
      ..setFloat(10, 0)
      ..setFloat(11, dpr)
      ..setFloat(12, 0);
  }

  void _paintGrain(Canvas canvas, Size size) {
    final image = _grain?.value;
    if (image == null) return;
    if (!identical(_grainImage, image)) {
      _grainPaint.shader = null;
      _grainShader?.dispose();
      _grainImage = image;
      _grainShader = ui.ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        (Matrix4.identity()
              ..scaleByDouble(160 / image.width, 160 / image.height, 1, 1))
            .storage,
        filterQuality: FilterQuality.low,
      );
      _grainPaint.shader = _grainShader;
    }
    canvas.save();
    canvas.translate(0, -size.height);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 3),
      _grainPaint,
    );
    canvas.restore();
  }
}
