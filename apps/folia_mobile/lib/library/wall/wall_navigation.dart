import 'dart:math' as math;

import 'wall_types.dart';

// Original directional scoring uses wholly-ahead rectangles, strict band overlap and stable source order on a complete tie. This is key-event work, never a display-frame search.
enum WallDirection { up, down, left, right }

T? pickAdjacentWallRect<T extends Object>(
  WallGeometry source,
  Iterable<({T value, WallGeometry rect})> candidates,
  WallDirection direction,
  WallMetrics metrics,
) {
  final horizontal =
          direction == WallDirection.left || direction == WallDirection.right,
      missPenalty = metrics.cellSize + metrics.gap,
      positive =
          direction == WallDirection.right || direction == WallDirection.down;
  double along(WallGeometry r) => horizontal ? r.x : r.y;
  double alongSize(WallGeometry r) => horizontal ? r.width : r.height;
  double cross(WallGeometry r) => horizontal ? r.y : r.x;
  double crossSize(WallGeometry r) => horizontal ? r.height : r.width;
  T? best;
  var bestScore = double.infinity, bestCross = double.infinity;
  for (final candidate in candidates) {
    final rect = candidate.rect,
        step = positive
            ? along(rect) - (along(source) + alongSize(source))
            : along(source) - (along(rect) + alongSize(rect));
    if (step < 0) continue;
    final overlap =
            math.min(
              cross(source) + crossSize(source),
              cross(rect) + crossSize(rect),
            ) -
            math.max(cross(source), cross(rect)),
        score = step + (overlap > 0 ? 0 : -overlap * 2 + missPenalty),
        drift =
            ((cross(rect) + crossSize(rect) / 2) -
                    (cross(source) + crossSize(source) / 2))
                .abs();
    if (score < bestScore || (score == bestScore && drift < bestCross)) {
      best = candidate.value;
      bestScore = score;
      bestCross = drift;
    }
  }
  return best;
}

T? findNearestWallRect<T extends Object>(
  Iterable<T> candidates,
  WallPoint point,
  WallGeometry Function(T) rectOf,
) {
  T? best;
  var bestDistance = double.infinity;
  for (final candidate in candidates) {
    final rect = rectOf(candidate),
        dx = rect.x + rect.width / 2 - point.x,
        dy = rect.y + rect.height / 2 - point.y,
        distance = dx * dx + dy * dy;
    if (distance < bestDistance) {
      best = candidate;
      bestDistance = distance;
    }
  }
  return best;
}
