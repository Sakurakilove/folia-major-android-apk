import 'package:flutter/painting.dart';

import '../../../wall/wall_css_paint.dart';
import '../../bravais_album_art.dart';
import '../bravais_card_palette.dart';

// Source CSS filter and isolated blend inputs. Finite scene tracks supply these values; this object never schedules frames or decodes another image.
enum BravaisArtShaderMode { mosaic, artist, shard }

class BravaisArtStyle {
  const BravaisArtStyle({
    required this.mode,
    this.placement,
    this.base = const Color(0x00000000),
    this.light = const Color(0x00000000),
    this.dark = const Color(0x00000000),
    this.grayscale = 0,
    this.contrast = 1,
    this.brightness = 1,
    this.opacity = 1,
    this.multiply = false,
    this.darkOpacity = 0,
    this.dotOpacity = 0,
    this.fallback = false,
    this.fallbackColors = const [Color(0x00000000), Color(0x00000000)],
  });
  factory BravaisArtStyle.artist({
    required BravaisCardPalette palette,
    required Color light,
    Color? dark,
    required double opacity,
    required bool fallback,
    required List<Color> fallbackColors,
  }) => BravaisArtStyle(
    mode: BravaisArtShaderMode.artist,
    base: palette.posterBackground,
    light: light,
    dark:
        dark ??
        wallSrgbMix(
          palette.daylight ? palette.ink : palette.background,
          light,
          palette.daylight ? .18 : .12,
        ),
    grayscale: 1,
    contrast: 1.15,
    brightness: 1.05,
    opacity: opacity,
    multiply: true,
    darkOpacity: 1,
    fallback: fallback,
    fallbackColors: fallbackColors,
  );
  final BravaisArtShaderMode mode;
  final BravaisArtPlacement? placement;
  final Color base, light, dark;
  final double grayscale,
      contrast,
      brightness,
      opacity,
      darkOpacity,
      dotOpacity;
  final bool multiply, fallback;
  final List<Color> fallbackColors;
  Rect? get backgroundRect {
    final p = placement;
    if (p == null) return null;
    // Source background-position/background-size are serialized with toFixed(1), even during album-wall reflows.
    double fixed(double value) => double.parse(value.toStringAsFixed(1));
    final size = fixed(p.size);
    return Rect.fromLTWH(fixed(p.x), fixed(p.y), size, size);
  }
}
