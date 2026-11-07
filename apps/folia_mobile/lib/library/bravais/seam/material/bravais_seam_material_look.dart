import 'package:flutter/painting.dart';

import '../../../wall/wall_css_paint.dart';
import '../../tiles/bravais_card_palette.dart';

// Original preset order, normalization and local print ink overrides. Clear-seam mode makes preset variables inactive; only default paper changes with see-through.
enum BravaisSeamStyle {
  paper,
  white,
  black,
  frost,
  dots,
  hatch,
  contour,
  check,
}

BravaisSeamStyle normalizeBravaisSeamStyle(Object? value) => BravaisSeamStyle
    .values
    .firstWhere((v) => v.name == value, orElse: () => BravaisSeamStyle.paper);

class BravaisSeamMaterialLook {
  const BravaisSeamMaterialLook({
    required this.palette,
    this.style = BravaisSeamStyle.paper,
    this.clear = false,
    this.seeThrough = false,
    this.backdropBlur = false,
  });
  final BravaisCardPalette palette;
  final BravaisSeamStyle style;
  final bool clear, seeThrough, backdropBlur;
  BravaisSeamStyle get effectiveStyle => clear ? BravaisSeamStyle.paper : style;
  bool get printed =>
      effectiveStyle == BravaisSeamStyle.white ||
      effectiveStyle == BravaisSeamStyle.black;
  bool get needsGrain => printed || effectiveStyle == BravaisSeamStyle.frost;
  bool get whiteGrain => effectiveStyle != BravaisSeamStyle.white;
  Color get paper {
    final p = palette;
    if (clear) {
      return p.background.withValues(
        alpha: p.background.a * (backdropBlur ? .5 : .64),
      );
    }
    return switch (style) {
      BravaisSeamStyle.white => const Color(0xfff7f6f2),
      BravaisSeamStyle.black => const Color(0xff101010),
      BravaisSeamStyle.frost => wallSrgbMix(
        p.background,
        p.accent,
        .2,
      ).withValues(alpha: wallSrgbMix(p.background, p.accent, .2).a * .82),
      _ => wallSrgbMix(p.background, p.ink, .1).withValues(
        alpha:
            wallSrgbMix(p.background, p.ink, .1).a *
            (style == BravaisSeamStyle.paper && seeThrough ? .8 : 1),
      ),
    };
  }

  Color get ink => effectiveStyle == BravaisSeamStyle.white
      ? const Color(0xff141414)
      : effectiveStyle == BravaisSeamStyle.black
      ? const Color(0xfff3f1ec)
      : palette.ink;
  Color get inkSoft => ink.withValues(
    alpha:
        ink.a *
        (effectiveStyle == BravaisSeamStyle.white
            ? .62
            : effectiveStyle == BravaisSeamStyle.black
            ? .64
            : .55),
  );
  Color get accent => printed ? ink : palette.accent;
  Color get secondary => printed ? inkSoft : palette.secondary;
}
