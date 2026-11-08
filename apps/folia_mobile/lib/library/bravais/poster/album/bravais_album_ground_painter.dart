part of 'bravais_album_ground_program.dart';

// Album ground stays outside posterSafeArea. Preserve its isolated blending group, full upper/lower bleed and independently animated paper/mask/ghost; source font/device acceptance remains explicit.
class BravaisAlbumGroundPainter extends ChangeNotifier {
  BravaisAlbumGroundPainter._(
    this.owner,
    this.composition,
    this.entrance,
    this.typography,
    this.ghost,
    this.dpr,
    this.colors,
    this._active,
  ) {
    _paperDots = owner._shader(owner.dots);
    _lowerDots = owner._shader(owner.dots);
    _hatch = owner._shader(owner.pattern);
    _configureDots(_paperDots, 9, 1, 1.3, colors.ink, .2);
    _configureDots(_lowerDots, 10, 1.4, 1.8, colors.paper, .18);
    _signals = [
      for (final part in [
        BravaisAlbumPart.paper,
        BravaisAlbumPart.hatch,
        BravaisAlbumPart.dots,
        BravaisAlbumPart.ghost,
      ])
        entrance.signal(part),
    ];
    _blockPaint.color = colors.block;
    // DstOver adds the opaque paper after sampling the transparent CSS dot tile,
    // so one clipped draw gives the element one antialiased edge.
    _paperPaint.colorFilter = ColorFilter.mode(colors.paper, BlendMode.dstOver);
    _grainPaint
      ..blendMode = BlendMode.overlay
      ..colorFilter = cssOpacityFilter(.22);
  }
  final BravaisAlbumGroundProgram owner;
  final BravaisAlbumComposition composition;
  final BravaisAlbumEntrance entrance;
  final WallTypography typography;
  final String ghost;
  final double dpr;
  final BravaisAlbumGroundColors colors;
  late final ui.FragmentShader _paperDots, _lowerDots, _hatch;
  late final List<ValueListenable<BravaisAlbumMotion>> _signals;
  final _paperPaint = Paint(),
      _blockPaint = Paint(),
      _hatchPaint = Paint(),
      _dotsPaint = Paint(),
      _maskPaint = Paint()..blendMode = BlendMode.dstIn,
      _grainPaint = Paint();
  final _hatchAlpha = Paint(), _dotsAlpha = Paint(), _ghostAlpha = Paint();
  final _tileImages = <ui.Image>[], _imageShaders = <ui.ImageShader>[];
  SvgNoiseImageLease? _grain;
  SvgNoiseImageLease? get grain => _grain;
  ui.Image? _grainImage;
  ui.ImageShader? _grainShader;
  ui.Shader? _mask;
  TextPainter? _ghostText;
  Size? _size;
  Rect _dotsRect = Rect.zero;
  double _ghostEm = 0;
  bool _ready = false, _attached = false, _closed = false, _active;
  void setActive(bool value) {
    if (_closed || _active == value) return;
    _active = value;
    if (value) notifyListeners();
    _sync();
  }

  Rect paintBounds(Size size) =>
      Rect.fromLTWH(0, -size.height, size.width, size.height * 3);
  void _changed() {
    if (_closed) return;
    notifyListeners();
    _sync();
  }

  void _sync() {
    final wanted = !_closed && _active && hasListeners;
    if (wanted == _attached) return;
    _attached = wanted;
    for (final signal in _signals) {
      if (wanted) {
        signal.addListener(_changed);
      } else {
        signal.removeListener(_changed);
      }
    }
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _sync();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _sync();
  }

  void _prepare(Size size) {
    _ensureImages();
    if (_size == size) return;
    _size = size;
    final width = size.width, height = size.height;
    _prepareHatch(size);
    _dotsRect = Rect.fromLTWH(
      width * .44,
      height * .6,
      width * .64,
      height * .34,
    );
    _maskPaint.shader = null;
    _mask?.dispose();
    _mask = ui.Gradient.radial(
      Offset.zero,
      1,
      const [Color(0xff000000), Color(0xff000000), Color(0x00000000)],
      const [0, .4, 1],
      TileMode.clamp,
      (Matrix4.identity()
            ..translateByDouble(_dotsRect.width / 2, _dotsRect.height / 2, 0, 1)
            ..scaleByDouble(_dotsRect.width / 2, _dotsRect.height / 2, 1, 1))
          .storage,
    );
    _maskPaint.shader = _mask;
    _ghostText?.dispose();
    _ghostText = null;
    _ghostEm = cssFloat32(math.min(420, height * .52));
    if (ghost.isNotEmpty) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = colors.paper.withValues(alpha: colors.paper.a * .16);
      _ghostText = TextPainter(
        text: TextSpan(
          text: cssNormalText(ghost),
          style: typography
              .style(_ghostEm, color: colors.paper, weight: 900, height: 1)
              .copyWith(foreground: stroke),
        ),
        textDirection: typography.direction,
        locale: typography.locale,
        maxLines: 1,
      )..layout();
    }
  }

  void _opacity(
    Canvas canvas,
    Rect bounds,
    double alpha,
    Paint paint,
    VoidCallback draw,
  ) {
    if (alpha <= 0) return;
    if (alpha < 1) {
      paint.colorFilter = cssOpacityFilter(alpha);
      canvas.saveLayer(bounds, paint);
    } else {
      canvas.save();
    }
    try {
      draw();
    } finally {
      canvas.restore();
    }
  }

  void paint(Canvas canvas, Size size) {
    if (_closed || size.isEmpty) return;
    _prepare(size);
    final bounds = Offset.zero & size,
        height = size.height,
        width = size.width,
        group = paintBounds(size),
        progress = entrance.sample(BravaisAlbumPart.paper).progress,
        left =
            height +
            (composition.divider.left / 100 * height - height) * progress,
        right =
            height +
            (composition.divider.right / 100 * height - height) * progress,
        paperPath = Path()
          ..moveTo(0, -height)
          ..lineTo(width, -height)
          ..lineTo(width, right)
          ..lineTo(0, left)
          ..close();
    canvas.save();
    canvas.clipRect(group);
    canvas.saveLayer(group, Paint());
    canvas.drawRect(bounds, _blockPaint);
    canvas.save();
    canvas.clipPath(paperPath);
    canvas.translate(0, -height);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height * 2), _paperPaint);
    canvas.restore();
    _opacity(
      canvas,
      bounds,
      entrance.sample(BravaisAlbumPart.hatch).opacity,
      _hatchAlpha,
      () {
        final left = composition.divider.left / 100 * height,
            right = composition.divider.right / 100 * height,
            path = Path()
              ..moveTo(0, left)
              ..lineTo(width, right)
              ..lineTo(width, right + height * .032)
              ..lineTo(0, left + height * .032)
              ..close();
        canvas.save();
        canvas.clipPath(path);
        canvas.drawRect(bounds, _hatchPaint);
        canvas.restore();
      },
    );
    _opacity(
      canvas,
      _dotsRect,
      entrance.sample(BravaisAlbumPart.dots).opacity,
      _dotsAlpha,
      () {
        canvas.save();
        canvas.translate(_dotsRect.left, _dotsRect.top);
        final local = Offset.zero & _dotsRect.size;
        canvas.saveLayer(local, Paint());
        canvas.drawRect(local, _dotsPaint);
        canvas.drawRect(local, _maskPaint);
        canvas.restore();
        canvas.restore();
      },
    );
    if (_ghostText != null) {
      _opacity(
        canvas,
        group,
        entrance.sample(BravaisAlbumPart.ghost).opacity,
        _ghostAlpha,
        () {
          final text = _ghostText;
          if (text == null) return;
          text.paint(
            canvas,
            Offset(
              composition.ghostSide == 'right'
                  ? width + cssFloat32(_ghostEm * .18) - text.width
                  : -cssFloat32(_ghostEm * .12),
              height + cssFloat32(_ghostEm * .12) - text.height,
            ),
          );
        },
      );
    }
    _paintGrain(canvas, size);
    canvas.restore();
    canvas.restore();
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _sync();
    _grain?.removeListener(_changed);
    _grain?.dispose();
    _grain = null;
    _grainPaint.shader = null;
    _grainShader?.dispose();
    _grainShader = null;
    _paperPaint.shader = null;
    _dotsPaint.shader = null;
    _hatchPaint.shader = null;
    _maskPaint.shader = null;
    _mask?.dispose();
    _mask = null;
    for (final shader in _imageShaders) {
      shader.dispose();
    }
    for (final image in _tileImages) {
      image.dispose();
    }
    _imageShaders.clear();
    _tileImages.clear();
    owner._release(_paperDots);
    owner._release(_lowerDots);
    owner._release(_hatch);
    _ghostText?.dispose();
    _ghostText = null;
    super.dispose();
  }
}
