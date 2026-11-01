import 'dart:math' as math;

import '../wall/flip_plan.dart';
import '../wall/wall_types.dart';

// Source home-tab wave lifts the far corner first, then lands nearest-to-farthest after the entire exit wave.
double bravaisWaveStagger(
  double x,
  double y,
  WallPoint corner,
  WallMetrics metrics,
) => math.min(
  340,
  (math.max(0, x - corner.x) + math.max(0, y - corner.y)) / metrics.pitch * 30,
);

class BravaisWaveStep {
  const BravaisWaveStep(this.key, this.to, this.outDelay, this.inDelay);
  final String key;
  final String? to;
  final int outDelay, inDelay;
  Map<String, Object?> toJson() => {
    'key': key,
    'to': to,
    'outDelay': outDelay,
    'inDelay': inDelay,
  };
}

class BravaisWallWavePlan {
  const BravaisWallWavePlan(this.steps, this.swaps, this.durationMs);
  final List<BravaisWaveStep> steps;
  final List<({String key, String? to})> swaps;
  final int durationMs;
  Map<String, Object> toJson() => {
    'steps': steps.map((s) => s.toJson()).toList(),
    'swaps': swaps.map((s) => {'key': s.key, 'to': s.to}).toList(),
    'durationMs': durationMs,
  };
}

BravaisWallWavePlan planBravaisWallWave(
  List<WallFaceChange> changes,
  WallBounds viewport,
  WallBounds visible,
  WallMetrics metrics, {
  int maxTiles = 400,
}) {
  final candidates = <({WallFaceChange change, double stagger, int index})>[],
      swaps = <({String key, String? to})>[];
  for (var i = 0; i < changes.length; i++) {
    final change = changes[i], slot = change.slot;
    if (change.from == change.to) continue;
    if (!slot.bounds.overlaps(visible)) {
      swaps.add((key: slot.key, to: change.to));
      continue;
    }
    candidates.add((
      change: change,
      stagger: bravaisWaveStagger(
        slot.x,
        slot.y,
        WallPoint(viewport.left, viewport.top),
        metrics,
      ),
      index: i,
    ));
  }
  candidates.sort((a, b) {
    final d = a.stagger.compareTo(b.stagger);
    return d == 0 ? a.index.compareTo(b.index) : d;
  });
  final steps = <BravaisWaveStep>[];
  var duration = 0;
  for (var i = 0; i < candidates.length; i++) {
    final c = candidates[i], change = c.change;
    if (i >= maxTiles) {
      swaps.add((key: change.slot.key, to: change.to));
      continue;
    }
    final outDelay = (340 - c.stagger + .5).floor(),
        inDelay = (620 + c.stagger + .5).floor();
    steps.add(BravaisWaveStep(change.slot.key, change.to, outDelay, inDelay));
    duration = math.max(duration, inDelay + 420);
  }
  return BravaisWallWavePlan(steps, swaps, duration);
}
