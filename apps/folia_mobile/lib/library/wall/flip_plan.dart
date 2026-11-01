import 'dart:math' as math;

import 'wall_slots.dart';
import 'wall_types.dart';

// Original split-flap scheduling keeps nearest visible changes, stable source ties and immediate swaps outside its existing tile budget.
class WallFaceChange {
  const WallFaceChange(this.slot, this.from, this.to);
  final WallSlot slot;
  final String? from, to;
}

class WallFlipOrigin {
  const WallFlipOrigin.point(this.x, this.y) : fromSeamEdges = false;
  const WallFlipOrigin.seamEdges(this.x) : y = 0, fromSeamEdges = true;
  final double x, y;
  final bool fromSeamEdges;
}

class WallFlipStep {
  const WallFlipStep(this.key, this.to, this.delay, this.direction);
  final String key;
  final String? to;
  final double delay;
  final int direction;
  Map<String, Object?> toJson() => {
    'key': key,
    'to': to,
    'delay': delay,
    'direction': direction,
  };
}

class WallFlipPlan {
  const WallFlipPlan(this.flips, this.swaps, this.unchanged, this.durationMs);
  final List<WallFlipStep> flips;
  final List<({String key, String? to})> swaps;
  final int unchanged;
  final double durationMs;
  Map<String, Object> toJson() => {
    'flips': flips.map((s) => s.toJson()).toList(),
    'swaps': swaps.map((s) => {'key': s.key, 'to': s.to}).toList(),
    'unchanged': unchanged,
    'durationMs': durationMs,
  };
}

double wallFlipDelay(double distance, WallMetrics metrics) =>
    math.min(420, distance / metrics.pitch * 18);
WallFlipPlan planWallFlip(
  List<WallFaceChange> changes,
  WallFlipOrigin origin,
  WallBounds visible,
  WallMetrics metrics, {
  int maxTiles = 400,
}) {
  final candidates = <({WallFaceChange change, double distance, int index})>[],
      swaps = <({String key, String? to})>[];
  var unchanged = 0;
  for (var i = 0; i < changes.length; i++) {
    final change = changes[i], slot = change.slot;
    if (change.from == change.to) {
      unchanged++;
      continue;
    }
    if (!slot.bounds.overlaps(visible)) {
      swaps.add((key: slot.key, to: change.to));
      continue;
    }
    final dx = slot.centerX - origin.x, dy = slot.centerY - origin.y;
    candidates.add((
      change: change,
      distance: origin.fromSeamEdges ? dx.abs() : math.sqrt(dx * dx + dy * dy),
      index: i,
    ));
  }
  candidates.sort((a, b) {
    final d = a.distance.compareTo(b.distance);
    return d == 0 ? a.index.compareTo(b.index) : d;
  });
  final flips = <WallFlipStep>[];
  var maxDelay = 0.0;
  for (var i = 0; i < candidates.length; i++) {
    final candidate = candidates[i], change = candidate.change;
    if (i >= maxTiles) {
      swaps.add((key: change.slot.key, to: change.to));
      continue;
    }
    final delay = wallFlipDelay(candidate.distance, metrics);
    maxDelay = math.max(maxDelay, delay);
    flips.add(
      WallFlipStep(
        change.slot.key,
        change.to,
        delay,
        change.slot.centerX < origin.x ? -1 : 1,
      ),
    );
  }
  return WallFlipPlan(
    flips,
    swaps,
    unchanged,
    flips.isEmpty ? 0 : maxDelay + 360,
  );
}
