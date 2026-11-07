import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../wall/wall_css_paint.dart';
import '../../wall/wall_box_shadows.dart';

// The playing card owns one inward accent stroke, strengthened by keyboard focus; it does not acquire a second outer accent ring.
class BravaisCurrentMark extends StatelessWidget {
  const BravaisCurrentMark({
    super.key,
    required this.accent,
    required this.shade,
    required this.focusStrength,
    this.shadows,
  });
  final Color accent, shade;
  final ValueListenable<double> focusStrength;
  final ValueListenable<List<WallBoxShadow>>? shadows;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _CurrentMark(accent, shade, focusStrength, shadows),
      child: const SizedBox.expand(),
    ),
  );
}

class _CurrentMark extends CustomPainter {
  _CurrentMark(this.accent, this.shade, this.focus, this.shadows)
    : super(repaint: shadows ?? focus);
  final Color accent, shade;
  final ValueListenable<double> focus;
  final ValueListenable<List<WallBoxShadow>>? shadows;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size, padding = rect.deflate(2), p = focus.value;
    if (shadows != null) {
      for (final shadow in shadows!.value.reversed) {
        shadow.paint(canvas, padding);
      }
    } else {
      // CSS shadow lists paint their first entry above the later glow.
      paintWallInsetShadow(
        canvas,
        padding,
        accent.withValues(alpha: accent.a * (.46 + .16 * p)),
        blur: 15 + 11 * p,
        spread: -7 + p,
      );
      paintWallInsetShadow(
        canvas,
        padding,
        shade.withValues(alpha: .52 + .1 * p),
        spread: 1,
      );
    }
    canvas.drawRect(
      rect.deflate(1),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CurrentMark old) =>
      old.accent != accent ||
      old.shade != shade ||
      old.focus != focus ||
      old.shadows != shadows;
}
