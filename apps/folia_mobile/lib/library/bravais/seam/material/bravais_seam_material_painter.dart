import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../../../rendering/gradients/css_gradient_program.dart';
import '../../../../rendering/noise/native_svg_noise.dart';
import '../../../../rendering/noise/svg_noise_provider.dart';
import '../../../../rendering/noise/svg_noise_texture.dart';
import '../bravais_seam_paper.dart';
import 'bravais_seam_material_look.dart';
import 'bravais_seam_material_program.dart';

part 'bravais_seam_material_patterns.dart';

// All eight source surfaces share their original paper/shadows. Grain appears on its real image-ready event; source gradients remain separate draws, without replacing any animated scene with a static image.
class BravaisSeamMaterialPainter extends CustomPainter {
  factory BravaisSeamMaterialPainter({
    required BravaisSeamMaterialLook look,
    required BravaisSeamMaterialProgram program,
    required double dpr,
  }) {
    final grain = look.needsGrain
        ? SvgNoiseImageLease(
            SvgNoiseProvider(
              native: program.noise,
              recipe: SvgNoiseRecipe.paper,
              cssExtent: 180,
              dpr: dpr,
              raw: true,
            ),
          )
        : null;
    return BravaisSeamMaterialPainter._(look, program, grain, dpr);
  }
  BravaisSeamMaterialPainter._(this.look, this.program, this.grain, this.dpr)
    : _paper = BravaisSeamPaper(
        palette: look.palette,
        seeThrough: look.seeThrough,
        clear: look.clear,
        backdropBlur: look.backdropBlur,
        customPaper: look.paper,
        paintClearEdge: false,
        includeInsetShadows: false,
      ),
      super(repaint: grain) {
    _grainPaint.colorFilter = svgPaperGrainFilter(look.whiteGrain);
    if (look.effectiveStyle == BravaisSeamStyle.dots) {
      _dots = program.createDots();
      final ink = look.ink;
      _dots!
        ..setFloat(1, ink.r)
        ..setFloat(2, ink.g)
        ..setFloat(3, ink.b)
        ..setFloat(4, ink.a * .16);
      final pixels = (9 * dpr).ceil();
      _dots!
        ..setFloat(0, 9)
        ..setFloat(5, pixels / 9);
      final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
      canvas.scale(pixels / 9, pixels / 9);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 9, 9), Paint()..shader = _dots);
      final picture = recorder.endRecording();
      _dotTile = picture.toImageSync(pixels, pixels);
      picture.dispose();
    }
    if (look.effectiveStyle == BravaisSeamStyle.frost) {
      _frost = program.gradients.createLinear();
    }
    final palette = look.palette;
    _frostColors = [
      palette.accent.withValues(alpha: palette.accent.a * .14),
      palette.secondary.withValues(alpha: palette.secondary.a * .12),
    ];
  }
  final BravaisSeamMaterialLook look;
  final BravaisSeamMaterialProgram program;
  final SvgNoiseImageLease? grain;
  final double dpr;
  final BravaisSeamPaper _paper;
  final _patterns = <Paint>[], _shaders = <ui.Shader>[];
  final _tiles = <String, ui.Image>{};
  ui.Image? _dotTile;
  final _grainPaint = Paint(), _dotsPaint = Paint();
  ui.Image? _grainImage;
  ui.ImageShader? _grainShader;
  ui.FragmentShader? _dots;
  CssLinearGradientEffect? _frost;
  late final List<Color> _frostColors;
  Size? _size;
  bool _closed = false;
  void _prepare(Size size) {
    if (_size == size) return;
    _size = size;
    for (final shader in _shaders) {
      if (shader is ui.FragmentShader) {
        program.releaseShader(shader);
      } else {
        shader.dispose();
      }
    }
    _shaders.clear();
    _patterns.clear();
    final dots = _dotTile;
    if (dots != null) {
      final shader = ui.ImageShader(
        dots,
        TileMode.repeated,
        TileMode.repeated,
        (Matrix4.identity()
              ..translateByDouble(size.width / 2 - 4.5, 0, 0, 1)
              ..scaleByDouble(9 / dots.width, 9 / dots.height, 1, 1))
            .storage,
        filterQuality: FilterQuality.low,
      );
      _shaders.add(shader);
      _dotsPaint.shader = shader;
    }
    _createPatterns(size);
    _grainImage = null;
  }

  void _add(ui.Shader shader) {
    _shaders.add(shader);
    _patterns.add(Paint()..shader = shader);
  }

  void _paintGrain(Canvas canvas, Rect bounds) {
    final image = grain?.value;
    if (image == null) return;
    if (!identical(image, _grainImage)) {
      _grainPaint.shader = null;
      _grainShader?.dispose();
      _grainImage = image;
      _grainShader = ui.ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        (Matrix4.identity()
              ..translateByDouble(bounds.width / 2 - 90, 0, 0, 1)
              ..scaleByDouble(180 / image.width, 180 / image.height, 1, 1))
            .storage,
        filterQuality: FilterQuality.low,
      );
      _grainPaint.shader = _grainShader;
    }
    canvas.drawRect(bounds, _grainPaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_closed || size.isEmpty) return;
    _prepare(size);
    final bounds = Offset.zero & size;
    _paper.paint(canvas, size);
    _paintGrain(canvas, bounds);
    final frost = _frost;
    if (frost != null) {
      frost.paint(canvas, bounds, 165, _frostColors, dither: true, dpr: dpr);
    }
    if (_dots != null) canvas.drawRect(bounds, _dotsPaint);
    for (final paint in _patterns) {
      canvas.drawRect(bounds, paint);
    }
    _paper.paintInsets(canvas, size);
  }

  @override
  bool shouldRepaint(BravaisSeamMaterialPainter oldDelegate) =>
      !identical(this, oldDelegate);
  void dispose() {
    if (_closed) return;
    _closed = true;
    _paper.dispose();
    _grainPaint.shader = null;
    _grainShader?.dispose();
    _grainShader = null;
    _dotsPaint.shader = null;
    final dots = _dots;
    if (dots != null) program.releaseShader(dots);
    _dots = null;
    _frost?.dispose();
    _frost = null;
    for (final shader in _shaders) {
      if (shader is ui.FragmentShader) {
        program.releaseShader(shader);
      } else {
        shader.dispose();
      }
    }
    _shaders.clear();
    _patterns.clear();
    _dotTile?.dispose();
    _dotTile = null;
    for (final image in _tiles.values) {
      image.dispose();
    }
    _tiles.clear();
    grain?.dispose();
  }
}
