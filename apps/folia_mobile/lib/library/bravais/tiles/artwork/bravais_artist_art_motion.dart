import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../../rendering/css_color.dart';
import '../../../../visualizer/motion/css_transition.dart';
import '../../../wall/wall_css_paint.dart';
import '../bravais_card_palette.dart';
import 'bravais_art_style.dart';

// Source light and ::after dark have independent 400ms CSS transitions: legacy sRGB versus modern Oklab. They cannot be derived from one interpolated color.
class BravaisArtistArtMotion extends ChangeNotifier
    implements ValueListenable<BravaisArtStyle> {
  BravaisArtistArtMotion({
    required this._frames,
    required this.nowMs,
    required BravaisCardPalette palette,
    required Color light,
    required bool restored,
    required this._fallback,
    required this._fallbackColors,
    required bool reducedMotion,
  }) : _palette = palette,
       _reduced = reducedMotion,
       _light = CssValueTransition(
         CssColorValue.legacy(light),
         CssColorValue.interpolate,
       ),
       _dark = CssValueTransition(
         CssColorValue.modern(_darkColor(palette, light)),
         CssColorValue.interpolate,
       ),
       _opacity = CssNumericTransition(restored ? 0 : 1) {
    _snapshot();
  }
  Listenable _frames;
  double Function() nowMs;
  BravaisCardPalette _palette;
  bool _fallback, _reduced, _attached = false, _closed = false;
  List<Color> _fallbackColors;
  final CssValueTransition<CssColorValue> _light, _dark;
  final CssNumericTransition _opacity;
  late BravaisArtStyle _value;
  @override
  BravaisArtStyle get value => _value;
  static Color _darkColor(BravaisCardPalette palette, Color light) =>
      wallSrgbMix(
        palette.daylight ? palette.ink : palette.background,
        light,
        palette.daylight ? .18 : .12,
      );
  void rebind(Listenable frames, double Function() clock) {
    nowMs = clock;
    if (identical(frames, _frames)) return;
    if (_attached) _frames.removeListener(_frame);
    _frames = frames;
    _attached = false;
    _sync();
  }

  void update({
    required BravaisCardPalette palette,
    required Color light,
    required bool restored,
    required bool fallback,
    required List<Color> fallbackColors,
    required bool reducedMotion,
  }) {
    if (_closed) return;
    final now = nowMs();
    _palette = palette;
    _fallback = fallback;
    _fallbackColors = fallbackColors;
    _reduced = reducedMotion;
    _light.setTarget(
      CssColorValue.legacy(light),
      now,
      const CssTransitionSpec(400),
      enabled: !_reduced,
    );
    _dark.setTarget(
      CssColorValue.modern(_darkColor(palette, light)),
      now,
      const CssTransitionSpec(400),
      enabled: !_reduced,
    );
    _opacity.setTarget(
      restored ? 0 : 1,
      now,
      const CssTransitionSpec(300, x1: 0, y1: 0, x2: .58, y2: 1),
      enabled: !_reduced,
    );
    _snapshot();
    _sync();
    notifyListeners();
  }

  void _advance() {
    final now = nowMs();
    _light.advance(now);
    _dark.advance(now);
    _opacity.advance(now);
    _snapshot();
  }

  void _snapshot() => _value = BravaisArtStyle.artist(
    palette: _palette,
    light: _light.value.color,
    dark: _dark.value.color,
    opacity: _opacity.value,
    fallback: _fallback,
    fallbackColors: _fallbackColors,
  );
  void _sync() {
    // Invisible color transitions keep their absolute timeline but need no display frames. Reattachment/restore samples their current values before exposing the image.
    final wanted =
        !_closed &&
        hasListeners &&
        (_opacity.value > 0 || _opacity.isAnimating) &&
        (_light.isAnimating || _dark.isAnimating || _opacity.isAnimating);
    if (wanted == _attached) return;
    _attached = wanted;
    if (wanted) {
      _frames.addListener(_frame);
    } else {
      _frames.removeListener(_frame);
    }
  }

  void _frame() {
    if (_closed) return;
    _advance();
    _sync();
    notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _advance();
    _sync();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _sync();
  }

  @override
  void dispose() {
    _closed = true;
    _sync();
    super.dispose();
  }
}
