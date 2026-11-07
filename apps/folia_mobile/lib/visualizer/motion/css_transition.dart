import 'package:flutter/foundation.dart';

import 'bezier.dart';

// CSS Transitions reversing-adjusted start and shortening factor differ from restarting a Flutter tween at its full duration.
class CssTransitionSpec {
  const CssTransitionSpec(
    this.durationMs, {
    this.delayMs = 0,
    this.x1 = .25,
    this.y1 = .1,
    this.x2 = .25,
    this.y2 = 1,
  });
  final double durationMs, delayMs, x1, y1, x2, y2;
  double ease(double progress) => cssBezier(x1, y1, x2, y2, progress);
}

class CssValueTransition<T> {
  CssValueTransition(this.value, this.interpolate);
  T value;
  final T Function(T from, T to, double progress) interpolate;
  _CssRun<T>? _run;
  bool get isAnimating => _run != null;
  T get target => _run?.to ?? value;
  void jump(T next) {
    value = next;
    _run = null;
  }

  void advance(double now) {
    final run = _run;
    if (run == null) return;
    final progress = run.progress(now);
    value = interpolate(run.from, run.to, run.spec.ease(progress));
    if (progress >= 1) {
      value = run.to;
      _run = null;
    }
  }

  void setTarget(
    T next,
    double now,
    CssTransitionSpec spec, {
    bool enabled = true,
  }) {
    advance(now);
    final old = _run;
    if (!enabled || spec.durationMs + spec.delayMs <= 0) {
      jump(next);
      return;
    }
    if (target == next) return;
    if (value == next) {
      jump(next);
      return;
    }
    final reverses = old != null && old.reverseStart == next;
    final factor = reverses
        ? (old.spec.ease(old.progress(now)) * old.factor + (1 - old.factor))
              .abs()
              .clamp(0.0, 1.0)
        : 1.0;
    final duration = spec.durationMs * factor,
        delay = spec.delayMs < 0 ? spec.delayMs * factor : spec.delayMs;
    _run = _CssRun<T>(
      value,
      next,
      now + delay,
      duration,
      spec,
      factor,
      reverses ? old.to : value,
    );
    advance(now);
  }
}

class CssNumericTransition extends CssValueTransition<double> {
  CssNumericTransition(double value)
    : super(value, (from, to, progress) => from + (to - from) * progress);
}

class _CssRun<T> {
  const _CssRun(
    this.from,
    this.to,
    this.start,
    this.duration,
    this.spec,
    this.factor,
    this.reverseStart,
  );
  final T from, to, reverseStart;
  final double start, duration, factor;
  final CssTransitionSpec spec;
  double progress(double now) => now < start
      ? 0
      : duration <= 0
      ? 1
      : ((now - start) / duration).clamp(0.0, 1.0);
}

// A control or card shares the scene clock and subscribes only while its CSS transition is running.
class CssNumericSignal extends ChangeNotifier
    implements ValueListenable<double> {
  CssNumericSignal(double initial, {required this.frames, required this.nowMs})
    : _transition = CssNumericTransition(initial);
  final Listenable frames;
  double Function() nowMs;
  final CssNumericTransition _transition;
  bool _attached = false, _closed = false;
  @override
  double get value => _transition.value;
  void setTarget(double next, CssTransitionSpec spec, {bool enabled = true}) {
    if (_closed) return;
    final previous = value;
    _transition.setTarget(next, nowMs(), spec, enabled: enabled);
    _sync();
    if (previous != value) notifyListeners();
  }

  void _frame() {
    if (_closed) return;
    final previous = value;
    _transition.advance(nowMs());
    _sync();
    if (previous != value) notifyListeners();
  }

  void _sync() {
    final wanted = !_closed && hasListeners && _transition.isAnimating;
    if (wanted == _attached) return;
    _attached = wanted;
    if (wanted) {
      frames.addListener(_frame);
    } else {
      frames.removeListener(_frame);
    }
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    final previous = value;
    _transition.advance(nowMs());
    _sync();
    if (previous != value) notifyListeners();
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
