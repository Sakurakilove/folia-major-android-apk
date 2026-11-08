import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../wall/wall_css_paint.dart';
import '../seam/bravais_seam_surface_cache.dart';

// Exact source fallback colors; resolved original poster/album palettes replace these discrete values when native artwork metadata is ready.
class BravaisPosterPaperColors {
  const BravaisPosterPaperColors({
    this.ground = const Color(0xff5f5f62),
    this.deep = const Color(0xff4c4c4f),
    this.edge = const Color(0xff3a3a3d),
    this.paper = const Color(0xffefe9dc),
    this.block = const Color(0xff22305f),
  });
  final Color ground, deep, edge, paper, block;
}

// Prepare one shared native program before the original seam's first-frame handoff. Closing the factory does not dispose live paper owners.
class BravaisPosterPaperProgram {
  BravaisPosterPaperProgram._(this.program);
  final ui.FragmentProgram program;
  final _shaders = <ui.FragmentShader>{};
  bool _closed = false;
  static Future<BravaisPosterPaperProgram> load() async =>
      BravaisPosterPaperProgram._(
        await ui.FragmentProgram.fromAsset('shaders/poster_paper.frag'),
      );
  BravaisPosterPaper create({
    required double viewportHeight,
    required double dpr,
    BravaisPosterPaperColors colors = const BravaisPosterPaperColors(),
    bool album = false,
  }) {
    if (_closed) throw StateError('Poster paper program is closed');
    ui.FragmentShader shader(double kind) {
      final result = program.fragmentShader();
      _shaders.add(result);
      result
        ..setFloat(0, kind)
        ..setFloat(3, viewportHeight)
        ..setFloat(4, dpr);
      void color(int offset, Color value) {
        result
          ..setFloat(offset, value.r)
          ..setFloat(offset + 1, value.g)
          ..setFloat(offset + 2, value.b)
          ..setFloat(offset + 3, value.a);
      }

      color(5, album ? colors.paper : colors.ground);
      color(9, album ? colors.block : colors.deep);
      color(13, colors.edge);
      color(17, wallSrgbMix(colors.edge, const Color(0xff000000), .3));
      return result;
    }

    return BravaisPosterPaper._(
      this,
      shader(album ? 2 : 0),
      album ? null : shader(1),
    );
  }

  void _release(ui.FragmentShader shader) {
    if (_shaders.remove(shader)) shader.dispose();
  }

  void dispose() => _closed = true;
}

// Static seam paper retains the original 40vh bleed, 90vh radial ellipse and right-edge veil. Ground decorations/UI are separate original layers and are not scaled or substituted by this surface.
class BravaisPosterPaper extends CustomPainter
    implements BravaisStaticSeamSurface {
  BravaisPosterPaper._(this.owner, this.base, this.veil) {
    _base.shader = base;
    _veil.shader = veil;
  }
  final BravaisPosterPaperProgram owner;
  final ui.FragmentShader base;
  final ui.FragmentShader? veil;
  final _base = Paint(), _veil = Paint();
  Size? _size;
  bool _closed = false;
  @override
  Rect cacheBounds(Size size) => Offset.zero & size;
  @override
  void paint(Canvas canvas, Size size) {
    if (_closed || size.isEmpty) return;
    if (_size != size) {
      _size = size;
      base
        ..setFloat(1, size.width)
        ..setFloat(2, size.height);
      veil
        ?..setFloat(1, size.width)
        ..setFloat(2, size.height);
    }
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, _base);
    if (veil != null) canvas.drawRect(bounds, _veil);
  }

  @override
  bool shouldRepaint(BravaisPosterPaper oldDelegate) =>
      !identical(this, oldDelegate);
  void dispose() {
    if (_closed) return;
    _closed = true;
    _base.shader = null;
    _veil.shader = null;
    owner._release(base);
    if (veil != null) owner._release(veil!);
  }
}
