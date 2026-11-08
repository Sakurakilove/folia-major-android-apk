import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../../rendering/css_numeric.dart';
import '../../../../rendering/css_opacity.dart';
import '../../../../rendering/css_text.dart';
import '../../../../rendering/noise/native_svg_noise.dart';
import '../../../../rendering/noise/svg_noise_provider.dart';
import '../../../wall/wall_typography.dart';
import '../bravais_album_composition.dart';
import 'bravais_album_entrance.dart';
import 'bravais_album_motion.dart';

part 'bravais_album_ground_painter.dart';
part 'bravais_album_ground_patterns.dart';

// Only original ground materials live here. Static SVG grain and tiny CSS gradient tiles keep full DPR; neither owns an animation clock or bitmap channel.
class BravaisAlbumGroundColors {
  const BravaisAlbumGroundColors({
    this.paper = const Color(0xffefe9dc),
    this.ink = const Color(0xff141210),
    this.block = const Color(0xff22305f),
  });
  final Color paper, ink, block;
}

class BravaisAlbumGroundProgram {
  BravaisAlbumGroundProgram._(this.dots, this.pattern, this.noise);
  final ui.FragmentProgram dots, pattern;
  final NativeSvgNoise noise;
  final _shaders = <ui.FragmentShader>{};
  bool _closed = false;
  static Future<BravaisAlbumGroundProgram> load({
    NativeSvgNoise? noise,
  }) async => BravaisAlbumGroundProgram._(
    await ui.FragmentProgram.fromAsset('shaders/poster_dots.frag'),
    await ui.FragmentProgram.fromAsset('shaders/seam_pattern.frag'),
    noise ?? NativeSvgNoise(),
  );
  BravaisAlbumGroundPainter create({
    required BravaisAlbumComposition composition,
    required BravaisAlbumEntrance entrance,
    required WallTypography typography,
    required String ghost,
    required double dpr,
    bool active = true,
    BravaisAlbumGroundColors colors = const BravaisAlbumGroundColors(),
  }) {
    if (_closed) throw StateError('Album ground program is closed');
    return BravaisAlbumGroundPainter._(
      this,
      composition,
      entrance,
      typography,
      ghost,
      dpr,
      colors,
      active,
    );
  }

  ui.FragmentShader _shader(ui.FragmentProgram program) {
    final shader = program.fragmentShader();
    _shaders.add(shader);
    return shader;
  }

  void _release(ui.FragmentShader shader) {
    if (_shaders.remove(shader)) shader.dispose();
  }

  void dispose() => _closed = true;
}
