import 'package:flutter/foundation.dart';

import '../../../../visualizer/motion/css_transition.dart';
import '../../../wall/wall_box_shadows.dart';
import '../../../wall/wall_css_filter.dart';
import '../bravais_card_look.dart';

// Independent CSS properties retain their own reversal state; one finite scene subscription drives the visible native card.
enum BravaisCardPhase { x, y, opacity, tint, dim, copy, glint, currentFocus }

class BravaisCardMotion extends ChangeNotifier {
  BravaisCardMotion({
    required BravaisCardLook look,
    required this._frames,
    required this.nowMs,
    this.reducedMotion = false,
    this._active = true,
  }) : _look = look,
       _filter = CssValueTransition(look.filter, WallCssFilter.interpolate),
       _currentShadows = CssValueTransition(
         WallShadowList(look.currentShadows),
         WallShadowList.interpolate,
       ),
       _shadows = CssValueTransition(
         WallShadowList(look.shadows),
         WallShadowList.interpolate,
       ) {
    for (final phase in BravaisCardPhase.values) {
      _tracks[phase] = CssNumericTransition(_target(phase, look));
      _signals[phase] = _CardValue(this, () => value(phase));
    }
    shadows = _CardValue(this, () => _shadows.value.shadows);
    currentShadows = _CardValue(this, () => _currentShadows.value.shadows);
  }
  BravaisCardLook _look;
  Listenable _frames;
  double Function() nowMs;
  bool reducedMotion;
  bool _active, _attached = false, _closed = false;
  final _tracks = <BravaisCardPhase, CssNumericTransition>{};
  final _signals = <BravaisCardPhase, ValueListenable<double>>{};
  final CssValueTransition<WallCssFilter> _filter;
  final CssValueTransition<WallShadowList> _shadows;
  final CssValueTransition<WallShadowList> _currentShadows;
  late final ValueListenable<List<WallBoxShadow>> shadows;
  late final ValueListenable<List<WallBoxShadow>> currentShadows;
  WallCssFilter get filter => _filter.value;
  BravaisCardLook get look => _look;
  double value(BravaisCardPhase phase) => _tracks[phase]!.value;
  ValueListenable<double> signal(BravaisCardPhase phase) => _signals[phase]!;
  bool get active => _active;
  set active(bool next) {
    if (_closed || next == _active) return;
    _active = next;
    if (next) _advance();
    _sync();
    notifyListeners();
  }

  double _target(BravaisCardPhase phase, BravaisCardLook look) =>
      switch (phase) {
        BravaisCardPhase.x => look.scaleX,
        BravaisCardPhase.y => look.scaleY,
        BravaisCardPhase.opacity => look.opacity,
        BravaisCardPhase.tint => look.tint,
        BravaisCardPhase.dim => look.dim,
        BravaisCardPhase.copy => look.copyAlpha,
        BravaisCardPhase.glint => look.focused ? 1 : 0,
        BravaisCardPhase.currentFocus => look.focused ? 1 : 0,
      };
  CssTransitionSpec _spec(BravaisCardPhase phase, BravaisCardLook look) =>
      switch (phase) {
        BravaisCardPhase.x || BravaisCardPhase.y => CssTransitionSpec(
          look.transformDuration,
          x1: 0,
          y1: 0,
          x2: .58,
          y2: 1,
        ),
        BravaisCardPhase.opacity => CssTransitionSpec(look.opacityDuration),
        BravaisCardPhase.glint => const CssTransitionSpec(200),
        BravaisCardPhase.currentFocus => const CssTransitionSpec(300),
        _ => const CssTransitionSpec(260),
      };

  void update(BravaisCardLook next) {
    if (_closed) return;
    final now = nowMs(), old = _look;
    _look = next;
    for (final phase in BravaisCardPhase.values) {
      final track = _tracks[phase]!, target = _target(phase, next);
      // A newly inserted ::before has no previous computed style from which to transition.
      if (phase == BravaisCardPhase.currentFocus &&
          old.current != next.current) {
        track.jump(target);
      } else {
        track.setTarget(
          target,
          now,
          _spec(phase, next),
          enabled: phase == BravaisCardPhase.currentFocus || !reducedMotion,
        );
      }
    }
    _filter.setTarget(
      next.filter,
      now,
      CssTransitionSpec(next.filterDuration),
      enabled: !reducedMotion && _filter.target.compatible(next.filter),
    );
    final nextShadows = WallShadowList(next.shadows);
    _shadows.setTarget(
      nextShadows,
      now,
      CssTransitionSpec(next.shadowDuration),
      enabled: !reducedMotion && _shadows.target.compatible(nextShadows),
    );
    if (!next.current || !old.current) {
      _currentShadows.jump(WallShadowList(next.currentShadows));
    } else {
      // The source reduced-motion selectors do not disable the current ::before shadow transition.
      _currentShadows.setTarget(
        WallShadowList(next.currentShadows),
        now,
        const CssTransitionSpec(300),
      );
    }
    _sync();
    notifyListeners();
  }

  void rebind(Listenable frames, double Function() clock) {
    nowMs = clock;
    if (identical(frames, _frames)) return;
    if (_attached) _frames.removeListener(_frame);
    _attached = false;
    _frames = frames;
    _sync();
  }

  void _advance() {
    final now = nowMs();
    for (final track in _tracks.values) {
      track.advance(now);
    }
    _filter.advance(now);
    _shadows.advance(now);
    _currentShadows.advance(now);
  }

  void _sync() {
    final wanted =
        !_closed &&
        _active &&
        hasListeners &&
        (_tracks.values.any((track) => track.isAnimating) ||
            _filter.isAnimating ||
            _shadows.isAnimating ||
            _currentShadows.isAnimating);
    if (wanted == _attached) return;
    _attached = wanted;
    if (wanted) {
      _frames.addListener(_frame);
    } else {
      _frames.removeListener(_frame);
    }
  }

  void _frame() {
    if (_closed) return;
    _advance();
    _sync();
    notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (_active) _advance();
    _sync();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _sync();
  }

  @override
  void dispose() {
    _closed = true;
    _sync();
    super.dispose();
  }
}

class _CardValue<T> implements ValueListenable<T> {
  const _CardValue(this.motion, this.read);
  final BravaisCardMotion motion;
  final T Function() read;
  @override
  T get value => read();
  @override
  void addListener(VoidCallback listener) => motion.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => motion.removeListener(listener);
}
