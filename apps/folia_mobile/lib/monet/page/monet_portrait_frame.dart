import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../rendering/css_shadows.dart';
import '../monet_portrait_image.dart';

// The original square/rectangular portrait surfaces, with independent live image crossfades and CSS shadow sigma.
class MonetPortraitFrame extends StatelessWidget {
  const MonetPortraitFrame({
    super.key,
    required this.square,
    required this.primary,
    required this.accent,
    required this.background,
    this.image,
    this.source,
  });
  final bool square;
  final Color primary, accent, background;
  final ImageProvider? image;
  final String? source;
  @override
  Widget build(BuildContext context) {
    final cover = MonetPortraitImage(image: image, source: source);
    if (square) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            cssBoxShadow(
              background.withValues(alpha: .45),
              const Offset(0, 36),
              80,
            ),
            cssBoxShadow(
              accent.withValues(alpha: .22),
              const Offset(0, 20),
              42,
            ),
            cssBoxShadow(
              primary.withValues(alpha: .06),
              Offset.zero,
              0,
              spread: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: ColoredBox(
            color: primary.withValues(alpha: .08),
            child: cover,
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34.4),
        boxShadow: [
          cssBoxShadow(
            background.withValues(alpha: .35),
            const Offset(0, 24),
            60,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34.4),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34.4),
              border: Border.all(color: primary.withValues(alpha: .1)),
              color: background.withValues(alpha: .15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(29.6),
                child: ColoredBox(
                  color: primary.withValues(alpha: .08),
                  child: cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
