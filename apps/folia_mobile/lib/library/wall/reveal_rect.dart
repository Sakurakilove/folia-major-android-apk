import 'dart:math' as math;

import 'seam_plan.dart';
import 'wall_types.dart';

// Original smallest camera move: rect visibility wins if it and the seam cannot both fit, and vertical visibility respects the player's current safe area.
WallPoint resolveWallRevealCenter({
  required WallGeometry rect,
  required WallPoint center,
  required WallView view,
  required WallMetrics metrics,
  required double? anchorX,
  required double seamWidth,
  double pad = 24,
  double? bottomInset,
  bool centered = false,
}) {
  final line = view.lineX,
      scale = view.scale,
      bottom = bottomInset ?? pad,
      hasSeam = anchorX != null && seamWidth > 1,
      offsets = hasSeam
          ? seamSplitOffsets(seamWidth, scale, metrics)
          : (left: 0.0, right: 0.0),
      rectCenter = rect.x + rect.width / 2,
      offset = anchorX != null && rectCenter < anchorX
          ? offsets.left
          : offsets.right,
      fitLow = rect.x + rect.width - (view.width - pad - line - offset) / scale,
      fitHigh = rect.x - (pad - line - offset) / scale,
      wantX = centered
          ? rectCenter - (view.width / 2 - line - offset) / scale
          : center.x;
  double clamp(double v, double low, double high) =>
      math.max(low, math.min(high, v));
  double x;
  if (hasSeam) {
    final need = seamWidth / 2 + wallSeamEdge,
        seamLow = anchorX - (view.width - need - line) / scale,
        seamHigh = anchorX + (line - need) / scale,
        low = math.max(fitLow, seamLow),
        high = math.min(fitHigh, seamHigh);
    x = low <= high
        ? clamp(wantX, low, high)
        : clamp(wantX, math.min(fitLow, fitHigh), math.max(fitLow, fitHigh));
  } else {
    x = clamp(wantX, math.min(fitLow, fitHigh), math.max(fitLow, fitHigh));
  }
  final yLow = rect.y + rect.height - (view.height / 2 - bottom) / scale,
      yHigh = rect.y - (pad - view.height / 2) / scale,
      wantY = centered
          ? rect.y +
                rect.height / 2 -
                ((pad + view.height - bottom) / 2 - view.height / 2) / scale
          : center.y,
      y = yLow <= yHigh ? clamp(wantY, yLow, yHigh) : rect.y + rect.height / 2;
  return WallPoint(x, y);
}
