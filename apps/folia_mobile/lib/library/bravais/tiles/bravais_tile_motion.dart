import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../rendering/js_number.dart';
import '../../wall/wall_types.dart';
import '../bravais_frame.dart';
import 'bravais_tile_flight.dart';
import 'bravais_tile_types.dart';
import '../bravais_wall_wave.dart';

// Content changes only at discrete source commits; finite face animation repaints its retained child without rebuilding the card per frame.
class BravaisTileMotion<T> extends ChangeNotifier {
  BravaisTileMotion({
    required this.frames,
    required this.nowMs,
    required BravaisTileFace<T> initial,
    BravaisEntrance? entrance,
    required WallRect rect,
  }) : _shown = initial,
       _target = initial,
       _mountEntranceToken = entrance?.token,
       face = ValueNotifier(initial) {
    _animationKey = _key(null, initial.key);
    setEntrance(entrance, rect);
  }
  Listenable frames;
  final double Function() nowMs;
  final ValueNotifier<BravaisTileFace<T>> face;
  final int? _mountEntranceToken;
  BravaisTileFace<T> _shown, _target;
  BravaisTileTransition _transition = BravaisTileTransition.none;
  BravaisFlipStep? _step, _outStep;
  BravaisTileFlight? _flight;
  int? _waveOutDoneToken, _entranceToken;
  String? _animationKey;
  bool _attached = false, _active = true, _closed = false, _reduced = false;
  BravaisTileSample sample = const BravaisTileSample();
  bool get animating => _flight != null;
  void rebindFrames(Listenable next) {
    if (_closed || identical(frames, next)) return;
    if (_attached) frames.removeListener(_frame);
    _attached = false;
    frames = next;
    _sync();
  }

  BravaisTileFlightKind? get flightKind => _flight?.kind;
  String _key(BravaisFlipStep? step, String? target) =>
      step?.waveInDelay != null
      ? 'wave:${step!.token}'
      : '${step?.token ?? ''}|${step == null ? '' : jsNumberString(step.delay)}|${target ?? 'null'}';
  void _refreshFace() {
    // The original reduced fade renders the new face during exit; ordinary flips keep the old face until 90 degrees.
    face.value = _transition == BravaisTileTransition.flip ? _shown : _target;
  }

  void setTarget(
    BravaisTileFace<T> target, {
    BravaisFlipStep? step,
    bool reducedMotion = false,
  }) {
    if (_closed) return;
    _target = target;
    _step = step;
    _reduced = reducedMotion;
    final transition = resolveBravaisTileTransition(
          _shown.key,
          target.key,
          step,
          reducedMotion,
        ),
        key = _key(step, target.key);
    final changed = key != _animationKey || transition != _transition;
    _animationKey = key;
    _transition = transition;
    if (!changed) {
      _refreshFace();
      return;
    }
    if (_flight?.outgoing ?? false) _flight = null;
    if (transition == BravaisTileTransition.swap) _shown = target;
    if (transition == BravaisTileTransition.flip ||
        transition == BravaisTileTransition.fade) {
      if (step!.waveInDelay != null && _waveOutDoneToken == step.token) {
        _shown = target;
        _transition = resolveBravaisTileTransition(
          _shown.key,
          target.key,
          step,
          reducedMotion,
        );
      } else {
        _outStep = step;
        final fade = transition == BravaisTileTransition.fade,
            wave = !fade && step.waveInDelay != null;
        _flight = BravaisTileFlight(
          fade
              ? BravaisTileFlightKind.fadeOut
              : wave
              ? BravaisTileFlightKind.waveOut
              : BravaisTileFlightKind.flipOut,
          nowMs() + (fade ? 0 : step.delay),
          fade
              ? 90
              : wave
              ? 280
              : 150,
          direction: step.direction,
        );
      }
    }
    _refreshFace();
    _draw();
    _sync();
  }

  void setEntrance(BravaisEntrance? entrance, WallRect rect) {
    if (_closed || entrance?.token == _entranceToken) return;
    _entranceToken = entrance?.token;
    if (entrance == null ||
        (entrance.mountsOnly && entrance.token != _mountEntranceToken) ||
        nowMs() >= entrance.until) {
      return;
    }
    final stagger = entrance.reduced
        ? 0
        : bravaisWaveStagger(rect.x, rect.y, entrance.corner, bravaisMetrics);
    _outStep = null;
    _flight = BravaisTileFlight(
      entrance.reduced
          ? BravaisTileFlightKind.entranceFade
          : BravaisTileFlightKind.waveIn,
      entrance.startedAt + stagger,
      entrance.reduced ? 180 : 420,
    );
    _draw();
    _sync();
  }

  void _draw() {
    final now = nowMs(), flight = _flight;
    if (flight != null && flight.done(now)) {
      if (flight.outgoing) {
        final step = _outStep!,
            fade = flight.kind == BravaisTileFlightKind.fadeOut,
            wave = flight.kind == BravaisTileFlightKind.waveOut;
        _shown = _target;
        if (wave) _waveOutDoneToken = step.token;
        _transition = resolveBravaisTileTransition(
          _shown.key,
          _target.key,
          _step,
          _reduced,
        );
        _refreshFace();
        final gap = wave
            ? math.max(0.0, step.waveInDelay! - step.delay - 280)
            : 0.0;
        _flight = BravaisTileFlight(
          fade
              ? BravaisTileFlightKind.fadeIn
              : wave
              ? BravaisTileFlightKind.waveIn
              : BravaisTileFlightKind.flipIn,
          now + gap,
          fade
              ? 90
              : wave
              ? 420
              : 210,
          direction: step.direction,
        );
      } else {
        _flight = null;
      }
    }
    sample = _flight?.sample(now) ?? const BravaisTileSample();
    notifyListeners();
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

  void setActive(bool active) {
    if (_closed || active == _active) return;
    _active = active;
    if (active) _draw();
    _sync();
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _sync();
    _flight = null;
    face.dispose();
    super.dispose();
  }
}
