import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

// CSS drop-shadow blurs the combined glyph alpha before opacity and scale, rather than replacing it with textShadow.
class StillTextShadow extends StatelessWidget {
  const StillTextShadow({
    super.key,
    required this.offset,
    required this.sigma,
    required this.alpha,
    required this.child,
  });
  final Offset offset;
  final double sigma, alpha;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Transform.translate(
              offset: offset,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Color.fromRGBO(0, 0, 0, alpha),
                    BlendMode.srcIn,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
      child,
    ],
  );
}
