import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

// The source's fixed-size radial surface is blurred locally; this is a painted glow, never a captured backdrop.
class SubtitleOverlayGlow extends StatelessWidget {
  const SubtitleOverlayGlow({
    super.key,
    required this.background,
    required this.enabled,
    required this.child,
  });
  final Color background;
  final bool enabled;
  final Widget child;
  @override
  Widget build(BuildContext context) => !enabled
      ? child
      : Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -40,
              right: -40,
              top: -24,
              bottom: -24,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: CustomPaint(
                      painter: _SubtitleGlowPainter(background),
                      isComplex: true,
                      willChange: false,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: child,
            ),
          ],
        );
}

class _SubtitleGlowPainter extends CustomPainter {
  _SubtitleGlowPainter(this.color);
  final Color color;
  final _paint = Paint();
  Size? _size;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_size != size) {
      _size = size;
      _paint.shader = ui.Gradient.radial(
        Offset.zero,
        1,
        [
          color.withValues(alpha: .96),
          color.withValues(alpha: .78),
          color.withValues(alpha: 0),
        ],
        const [0, .62, 1],
      );
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width * 1.15, size.height * 1.3);
    canvas.drawRect(
      Rect.fromLTWH(-1 / 2.3, -1 / 2.6, 1 / 1.15, 1 / 1.3),
      _paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SubtitleGlowPainter old) => old.color != color;
}
