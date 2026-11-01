import 'dart:ui' as ui;

import '../visualizer/motion/color_value.dart';
import 'partita_chunk_motion.dart';

class PartitaGuideColors {
  PartitaGuideColors(String css, ui.Color Function(String) resolveColor)
    : active = resolveColor(css),
      vertical = _suffix(css, '45'),
      horizontal = _suffix(css, '35');
  final ui.Color active;
  final ui.Color? vertical, horizontal;
  static ui.Color? _suffix(String css, String suffix) {
    final c = MotionRgba.parse('$css$suffix');
    return c == null
        ? null
        : ui.Color.fromRGBO(
            c.red.round(),
            c.green.round(),
            c.blue.round(),
            c.alpha,
          );
  }
}

// Preserve the source left/right guide rectangles, immediate state colors, suffix-hex shadows and independent JS/CSS reveal curves.
class PartitaGuidePaint {
  final _group = ui.Paint(),
      _fill = ui.Paint(),
      _shadow = ui.Paint()
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5);
  void paint(
    ui.Canvas canvas,
    ui.Size chunkSize,
    PartitaChunkMotion motion,
    PartitaGuideColors colors,
  ) {
    if (!motion.showGuides) return;
    final alpha = motion.guideOpacity.value.clamp(0.0, 1.0),
        scale = motion.guideScale.value;
    if (alpha <= 0 || scale == 0) return;
    final color = motion.status == 'active'
        ? colors.active
        : ui.Color.fromRGBO(
            255,
            255,
            255,
            motion.status == 'passed' ? .22 : .14,
          );
    void line(
      ui.Rect rect,
      ui.Offset origin,
      bool vertical,
      ui.Color? shadowColor,
    ) {
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.scale(vertical ? 1 : scale, vertical ? scale : 1);
      canvas.translate(-origin.dx, -origin.dy);
      canvas.saveLayer(
        rect.inflate(24),
        _group..color = ui.Color.fromRGBO(255, 255, 255, alpha),
      );
      if (shadowColor != null) {
        canvas.drawRect(rect, _shadow..color = shadowColor);
      }
      canvas.drawRect(rect, _fill..color = color);
      canvas.restore();
      canvas.restore();
    }

    final left = motion.left;
    final verticalX = left ? -8.0 : chunkSize.width + 7;
    line(
      ui.Rect.fromLTWH(verticalX, chunkSize.height - 16, 1, 32),
      ui.Offset(verticalX + .5, chunkSize.height + 16),
      true,
      motion.status == 'active' ? colors.vertical : null,
    );
    final horizontalX = left ? -16.0 : -20.0, width = chunkSize.width + 36;
    line(
      ui.Rect.fromLTWH(horizontalX, chunkSize.height + 7, width, 1),
      ui.Offset(
        left ? horizontalX : horizontalX + width,
        chunkSize.height + 7.5,
      ),
      false,
      motion.status == 'active' ? colors.horizontal : null,
    );
  }
}
