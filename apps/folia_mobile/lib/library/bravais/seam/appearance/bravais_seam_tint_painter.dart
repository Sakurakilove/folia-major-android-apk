import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../../rendering/gradients/css_gradient_program.dart';
import '../../tiles/bravais_card_palette.dart';
import 'bravais_seam_appearance.dart';

// The foreground switches immediately between tint and the day/night lights-out fill, retaining its CSS opacity transition. Gradient uniforms and colors are cached by owner.
class BravaisSeamTintPainter extends CustomPainter {
  BravaisSeamTintPainter(
    this.appearance,
    this.gradients, {
    required this.foreground,
  }) : super(
         repaint: Listenable.merge([
           appearance,
           foreground ? appearance.textTint : appearance.paperTint,
         ]),
       );
  final BravaisSeamAppearance appearance;
  final CssGradientProgram gradients;
  final bool foreground;
  final _paint = Paint();
  CssLinearGradientEffect? _gradient;
  BravaisCardPalette? _palette;
  List<Color> _colors = const [];
  @override
  void paint(Canvas canvas, Size size) {
    final alpha = foreground
        ? appearance.textTint.value
        : appearance.paperTint.value;
    if (alpha <= 0 || size.isEmpty) return;
    final look = appearance.look,
        palette = look.palette,
        bounds = Offset.zero & size;
    final solid = foreground && look.lightsOut
        ? palette.shade
        : palette.customTint;
    if (solid != null) {
      canvas.drawRect(
        bounds,
        _paint..color = solid.withValues(alpha: solid.a * alpha),
      );
      return;
    }
    if (!identical(palette, _palette)) {
      _palette = palette;
      _colors = palette.tintColors;
    }
    (_gradient ??= gradients.createLinear()).paint(
      canvas,
      bounds,
      145,
      _colors,
      opacity: alpha,
    );
  }

  @override
  bool shouldRepaint(BravaisSeamTintPainter oldDelegate) =>
      !identical(appearance, oldDelegate.appearance) ||
      foreground != oldDelegate.foreground;
  void dispose() {
    _gradient?.dispose();
    _gradient = null;
  }
}
