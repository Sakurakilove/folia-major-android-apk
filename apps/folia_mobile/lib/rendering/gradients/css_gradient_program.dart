import 'dart:math' as math;
import 'dart:ui' as ui;

import '../css_color.dart';
import '../css_color_matrices.dart';

part 'css_linear_gradient.dart';

// Modern CSS gradient stops interpolate in premultiplied Oklab. Prepare one native program before the wall's first-frame handoff, retaining each live owner's uniforms.
class CssGradientProgram {
  CssGradientProgram._(this.program);
  final ui.FragmentProgram program;
  final _shaders = <ui.FragmentShader>{};
  bool _closed = false;
  static Future<CssGradientProgram> load() async => CssGradientProgram._(
    await ui.FragmentProgram.fromAsset('shaders/css_gradient.frag'),
  );
  CssLinearGradientEffect createLinear() {
    if (_closed) throw StateError('CSS gradient program is closed');
    final shader = program.fragmentShader();
    var index = 13;
    for (final matrix in [cssLabToLms, cssLmsToRgb]) {
      for (final row in matrix) {
        for (final v in row) {
          shader.setFloat(index++, v);
        }
      }
    }
    _shaders.add(shader);
    return CssLinearGradientEffect._(this, shader);
  }

  void _release(ui.FragmentShader shader) {
    if (_shaders.remove(shader)) shader.dispose();
  }

  void dispose() {
    _closed = true;
  }
}
