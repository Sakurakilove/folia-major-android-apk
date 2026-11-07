import 'dart:ui' as ui;

import '../../../../rendering/gradients/css_gradient_program.dart';
import '../../../../rendering/noise/native_svg_noise.dart';

// Preload the original procedural pattern programs once. Each live surface owns its shaders; closing the factory never invalidates a retained surface.
class BravaisSeamMaterialProgram {
  BravaisSeamMaterialProgram._(
    this.dotsProgram,
    this.patternProgram,
    this.gradients,
    this.noise,
  );
  final ui.FragmentProgram dotsProgram;
  final ui.FragmentProgram patternProgram;
  final CssGradientProgram gradients;
  final NativeSvgNoise noise;
  bool _closed = false;
  final _shaders = <ui.FragmentShader>{};
  static Future<BravaisSeamMaterialProgram> load({
    required CssGradientProgram gradients,
    NativeSvgNoise? noise,
  }) async => BravaisSeamMaterialProgram._(
    await ui.FragmentProgram.fromAsset('shaders/seam_dots.frag'),
    await ui.FragmentProgram.fromAsset('shaders/seam_pattern.frag'),
    gradients,
    noise ?? NativeSvgNoise(),
  );
  ui.FragmentShader createDots() {
    if (_closed) throw StateError('Seam material program is closed');
    final shader = dotsProgram.fragmentShader();
    _shaders.add(shader);
    return shader;
  }

  ui.FragmentShader createPattern() {
    if (_closed) throw StateError('Seam material program is closed');
    final shader = patternProgram.fragmentShader();
    _shaders.add(shader);
    return shader;
  }

  void releaseShader(ui.FragmentShader shader) {
    if (_shaders.remove(shader)) shader.dispose();
  }

  void dispose() => _closed = true;
}
