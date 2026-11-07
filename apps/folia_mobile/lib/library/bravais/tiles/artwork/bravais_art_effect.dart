import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../../artwork/wall_artwork_effect.dart';
import 'bravais_art_program.dart';
import 'bravais_art_style.dart';

// One full-resolution image sampler performs the source artist/shard isolated filter/blends. Animated images stay on the retained native image stream.
class BravaisArtEffect extends WallArtworkEffect {
  BravaisArtEffect(BravaisArtProgram program, this.style)
    : _shader = program.createShader(),
      _empty = program.empty,
      _program = program {
    _paint.shader = _shader;
  }
  final ValueListenable<BravaisArtStyle> style;
  final ui.FragmentShader _shader;
  final BravaisArtProgram _program;
  late final _ArtUniforms _uniforms = _ArtUniforms(_shader);
  double? _placementSize, _placementX, _placementY;
  ui.Rect? _placementRect;
  final ui.Image _empty;
  final _paint = ui.Paint();
  ui.Image? _bound, _underBound;
  bool _listening = false, _closed = false;
  @override
  bool get needsImage => style.value.opacity > 0;
  @override
  void imageChanged(ui.Image? image) {
    if (_closed || identical(image, _bound)) return;
    _bound = image;
    _shader.setImageSampler(
      0,
      image ?? _empty,
      filterQuality: ui.FilterQuality.low,
    );
  }

  @override
  void underlayChanged(ui.Image? image) {
    if (_closed || identical(image, _underBound)) return;
    _underBound = image;
    _shader.setImageSampler(
      1,
      image ?? _empty,
      filterQuality: ui.FilterQuality.low,
    );
  }

  void _changed() => notifyListeners();
  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (!_listening && !_closed) {
      _listening = true;
      style.addListener(_changed);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (_listening && !hasListeners) {
      _listening = false;
      style.removeListener(_changed);
    }
  }

  void _color(int offset, ui.Color color) {
    _uniforms.setFloat(offset, color.r);
    _uniforms.setFloat(offset + 1, color.g);
    _uniforms.setFloat(offset + 2, color.b);
    _uniforms.setFloat(offset + 3, color.a);
  }

  @override
  void paint(
    ui.Canvas canvas,
    ui.Offset offset,
    ui.Size size,
    ui.Image? image,
  ) {
    if (_closed || size.isEmpty) return;
    final s = style.value;
    imageChanged(image);
    if (s.opacity <= 0) return;
    final ui.Rect rect;
    final placement = s.placement;
    if (placement == null) {
      _placementRect = null;
      _placementSize = _placementX = _placementY = null;
    } else if (_placementSize != placement.size ||
        _placementX != placement.x ||
        _placementY != placement.y) {
      _placementSize = placement.size;
      _placementX = placement.x;
      _placementY = placement.y;
      _placementRect = s.backgroundRect;
    }
    final fixed = _placementRect;
    if (fixed != null) {
      rect = fixed;
    } else if (image == null) {
      rect = ui.Offset.zero & size;
    } else {
      final scale = math.max(
            size.width / image.width,
            size.height / image.height,
          ),
          width = image.width * scale,
          height = image.height * scale;
      rect = ui.Rect.fromLTWH(
        (size.width - width) / 2,
        (size.height - height) / 2,
        width,
        height,
      );
    }
    _uniforms
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, rect.left)
      ..setFloat(3, rect.top)
      ..setFloat(4, rect.width)
      ..setFloat(5, rect.height);
    _color(6, s.base);
    _color(10, s.light);
    _color(14, s.dark);
    _uniforms
      ..setFloat(18, s.grayscale)
      ..setFloat(19, s.contrast)
      ..setFloat(20, s.brightness)
      ..setFloat(21, s.opacity)
      ..setFloat(
        22,
        image != null
            ? 2
            : s.fallback
            ? 1
            : 0,
      )
      ..setFloat(23, s.multiply ? 1 : 0)
      ..setFloat(24, s.darkOpacity)
      ..setFloat(25, s.dotOpacity);
    _color(26, s.fallbackColors[0]);
    _color(30, s.fallbackColors[1]);
    _uniforms
      ..setFloat(34, image?.width.toDouble() ?? 1)
      ..setFloat(35, image?.height.toDouble() ?? 1)
      ..setFloat(36, s.mode.index.toDouble());
    _uniforms
      ..setFloat(37, _underBound?.width.toDouble() ?? 1)
      ..setFloat(38, _underBound?.height.toDouble() ?? 1)
      ..setFloat(39, _underBound == null ? 0 : 1);
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.drawRect(ui.Offset.zero & size, _paint);
    canvas.restore();
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    if (_listening) style.removeListener(_changed);
    _listening = false;
    _bound = null;
    _underBound = null;
    _paint.shader = null;
    _program.releaseShader(_shader);
    super.dispose();
  }
}

// Store original doubles so unchanged uniforms are skipped without Float32 rounding causing false changes.
class _ArtUniforms {
  _ArtUniforms(this.shader);
  final ui.FragmentShader shader;
  final _values = List<double>.filled(40, double.nan);
  void setFloat(int index, double value) {
    if (_values[index] == value) return;
    _values[index] = value;
    shader.setFloat(index, value);
  }
}
