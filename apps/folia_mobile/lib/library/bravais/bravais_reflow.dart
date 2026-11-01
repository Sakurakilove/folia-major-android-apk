import 'package:flutter/foundation.dart';

import '../wall/wall_reflow_motion.dart';
import '../wall/wall_types.dart';

// A single finite frame subscription produces both tile rectangles and plate holes, including interrupted return tracks in other blocks.
final bravaisReflowCurve = WallReflowCurve(12 * 136 - 8);

class BravaisReflowTrack {
  const BravaisReflowTrack(this.from, this.to, this.start);
  final WallRect from, to;
  final double start;
  bool done(double now) => now - start >= bravaisReflowCurve.durationMs;
  WallRect sample(double now) {
    final p = ((now - start) / bravaisReflowCurve.durationMs).clamp(0.0, 1.0);
    return p >= 1 ? to : from.mix(to, bravaisReflowCurve.ease(p));
  }
}

Map<String, BravaisReflowTrack> planBravaisReflowTracks(
  Map<String, BravaisReflowTrack> tracks,
  Map<String, WallRect> previous,
  Map<String, WallRect> next,
  double now,
  WallRect? Function(String) resting,
) {
  final result = <String, BravaisReflowTrack>{
    for (final e in tracks.entries)
      if (!e.value.done(now)) e.key: e.value,
  };
  for (final key in {...previous.keys, ...next.keys}) {
    final rest = resting(key),
        running = result[key],
        from = running?.sample(now) ?? previous[key] ?? rest,
        to = next[key] ?? rest;
    if (from == null || to == null || from.same(to)) {
      result.remove(key);
      continue;
    }
    result[key] = BravaisReflowTrack(from, to, now);
  }
  return result;
}

class BravaisReflow extends ValueNotifier<Map<String, WallRect>> {
  BravaisReflow({
    required this.frames,
    required this.nowMs,
    required this.resting,
    Map<String, WallRect> initial = const {},
  }) : _targets = initial,
       super(Map.unmodifiable(initial));
  final Listenable frames;
  final double Function() nowMs;
  final WallRect? Function(String) resting;
  Map<String, WallRect> _targets;
  Map<String, BravaisReflowTrack> _tracks = {};
  bool _attached = false, _closed = false, _active = true;
  bool get animating => _tracks.isNotEmpty;
  void updateTargets(Map<String, WallRect> next, {bool enabled = true}) {
    if (_closed || identical(next, _targets)) return;
    final previous = _targets;
    _targets = next;
    if (!enabled) {
      _tracks = {};
      value = Map.unmodifiable(next);
      _sync();
      return;
    }
    _tracks = planBravaisReflowTracks(
      _tracks,
      previous,
      next,
      nowMs(),
      resting,
    );
    _draw();
    _sync();
  }

  void _draw() {
    final now = nowMs(), rects = <String, WallRect>{..._targets};
    for (final entry in _tracks.entries.toList(growable: false)) {
      rects[entry.key] = entry.value.sample(now);
      if (entry.value.done(now)) _tracks.remove(entry.key);
    }
    value = Map.unmodifiable(rects);
  }

  void _frame() {
    if (_closed || !_active) return;
    _draw();
    _sync();
  }

  void _sync() {
    final wanted = !_closed && _active && animating;
    if (wanted == _attached) return;
    _attached = wanted;
    if (wanted) {
      frames.addListener(_frame);
    } else {
      frames.removeListener(_frame);
    }
  }

  void setActive(bool value) {
    if (_closed || value == _active) return;
    _active = value;
    if (value) _draw();
    _sync();
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _sync();
    _tracks.clear();
    super.dispose();
  }
}
