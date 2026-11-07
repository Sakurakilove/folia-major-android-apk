import 'dart:math' as math;

import '../../tiles/bravais_card_palette.dart';
import '../bravais_seam_level.dart';

// The source has two tint layers: paper receives the full effective tint, while text is capped at .35. Clear seams fade only their body when lights are out.
class BravaisSeamLook {
  const BravaisSeamLook({
    required this.palette,
    required this.variant,
    this.wallClear = false,
    this.clearSeam = false,
    this.tinted = false,
    this.lightsOut = false,
    this.hovered = false,
    this.focusVisible = false,
    this.menuOpen = false,
    this.keyboardWindow = false,
  });
  final BravaisCardPalette palette;
  final BravaisSeamVariant variant;
  final bool wallClear,
      clearSeam,
      tinted,
      lightsOut,
      hovered,
      focusVisible,
      menuOpen,
      keyboardWindow;
  bool get exempt =>
      hovered ||
      focusVisible ||
      menuOpen ||
      keyboardWindow ||
      variant == BravaisSeamVariant.form ||
      variant == BravaisSeamVariant.search;
  double get _tint =>
      !exempt && tinted && !lightsOut && !wallClear && !clearSeam
      ? palette.tintOpacity.clamp(0.0, 1.0)
      : 0;
  double get paperTint => 1 - (1 - _tint) / (1 - math.min(_tint, .35));
  double get textTint => math.max(
    math.min(_tint, .35),
    !exempt && lightsOut && !wallClear && !clearSeam ? .6 : 0,
  );
  double get bodyOpacity =>
      !exempt && lightsOut && (wallClear || clearSeam) ? .4 : 1;
}
