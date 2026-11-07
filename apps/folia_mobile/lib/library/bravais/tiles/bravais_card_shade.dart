import 'package:flutter/widgets.dart';

import '../../wall/wall_css_paint.dart';

// Source poster scrim variants are retained as native gradients. Transparent cards still use the original actual cascade, not its descriptive comments.
class BravaisCardShade extends StatelessWidget {
  const BravaisCardShade({
    super.key,
    required this.shade,
    required this.expanded,
    this.mosaic = false,
  });
  final Color shade;
  final bool expanded, mosaic;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _CardShade(shade, expanded, mosaic),
      child: const SizedBox.expand(),
    ),
  );
}

class _CardShade extends CustomPainter {
  const _CardShade(this.shade, this.expanded, this.mosaic);
  final Color shade;
  final bool expanded, mosaic;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    Color a(double opacity) => shade.withValues(alpha: opacity);
    if (expanded) {
      // CSS backgrounds paint their first listed layer on top.
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = wallLinearGradient(
            bounds,
            90,
            [a(.88), a(.5), a(.08)],
            stops: [0, .52, 1],
          ),
      );
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = wallLinearGradient(
            bounds,
            0,
            [a(.86), a(.62), a(.26), a(0)],
            stops: [0, .14, .30, .46],
          ),
      );
    } else if (mosaic) {
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = wallLinearGradient(
            bounds,
            180,
            [a(0), a(.12), a(.4)],
            stops: [.55, .74, 1],
          ),
      );
    } else {
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = wallLinearGradient(
            bounds,
            180,
            [a(.05), a(.24), a(.92)],
            stops: [.34, .56, 1],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_CardShade old) =>
      old.shade != shade || old.expanded != expanded || old.mosaic != mosaic;
}
