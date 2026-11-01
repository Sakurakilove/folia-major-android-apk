import 'dart:math' as math;

import 'wall_slots.dart';
import 'wall_types.dart';

// A seam belongs to a block boundary in world space. Yield only enough camera distance to fit its full opening.
const wallSeamEdge = 14.0;
double _offset(WallMetrics metrics, double width) =>
    (width - wallBlockSize(metrics).width + metrics.gap) / 2;
double seamBoundaryX(int column, WallMetrics metrics, {double? blockWidth}) {
  final width = blockWidth ?? wallBlockSize(metrics).width;
  return column * width - _offset(metrics, width);
}

double nearestSeamBoundaryX(
  double x,
  WallMetrics metrics, {
  double? blockWidth,
}) {
  final width = blockWidth ?? wallBlockSize(metrics).width;
  return seamBoundaryX(
    ((x + _offset(metrics, width)) / width + .5).floor(),
    metrics,
    blockWidth: width,
  );
}

bool isSeamBoundaryX(double x, WallMetrics metrics) =>
    (nearestSeamBoundaryX(x, metrics) - x).abs() < 1e-6;

({double x, double cameraX, double shift}) blockSeamPlan({
  required double cameraX,
  required double openWidth,
  required WallView view,
  required WallMetrics metrics,
  double? blockWidth,
  double? preferX,
  double edge = wallSeamEdge,
}) {
  final width = blockWidth ?? wallBlockSize(metrics).width,
      need = openWidth / 2 + edge,
      base = ((cameraX + metrics.gap / 2) / width + .5).floor();
  final candidates = preferX == null
      ? [
          for (var c = base - 1; c <= base + 1; c++)
            seamBoundaryX(c, metrics, blockWidth: width),
        ]
      : [preferX];
  ({double x, double cameraX, double shift})? best;
  var bestScore = double.infinity;
  for (final x in candidates) {
    final screenX = view.lineX + (x - cameraX) * view.scale,
        fitX = math.max(need, math.min(view.width - need, screenX)),
        next = x - (fitX - view.lineX) / view.scale,
        shift = (next - cameraX).abs() * view.scale,
        score = shift + (fitX - view.lineX).abs() * .15;
    if (best == null || score < bestScore) {
      best = (x: x, cameraX: next, shift: shift);
      bestScore = score;
    }
  }
  return best!;
}

enum WallSeamSide { left, right }

({double screenX, double width, bool collapsed, WallSeamSide side})
seamGeometry({
  required double anchorX,
  required double cameraX,
  required double openWidth,
  required WallView view,
  double edge = wallSeamEdge,
}) {
  final x = view.lineX + (anchorX - cameraX) * view.scale,
      room = math.min(x, view.width - x) - edge,
      width = math.max(0.0, math.min(openWidth, room * 2));
  return (
    screenX: x,
    width: width,
    collapsed: openWidth > 1 && width < 2,
    side: x < view.lineX ? WallSeamSide.left : WallSeamSide.right,
  );
}

({double min, double max}) seamCameraSpan({
  required double anchorX,
  required double openWidth,
  required WallView view,
  double edge = wallSeamEdge,
}) {
  final need = openWidth / 2 + edge,
      min = anchorX - (view.width - need - view.lineX) / view.scale,
      max = anchorX + (view.lineX - need) / view.scale;
  if (min <= max) return (min: min, max: max);
  final center = anchorX - (view.width / 2 - view.lineX) / view.scale;
  return (min: center, max: center);
}

({double left, double right}) seamSplitOffsets(
  double width,
  double scale,
  WallMetrics metrics,
) {
  final pad = metrics.gap / 2 * scale * math.min(1, width / 16);
  return (left: -width / 2 - pad, right: width / 2 + pad);
}
