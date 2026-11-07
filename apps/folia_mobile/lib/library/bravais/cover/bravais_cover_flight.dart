import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../visualizer/motion/bezier.dart';
import 'bravais_cover_quad.dart';

// The flight is one continuous source animation, including the original switched hard-shadow color, rounded opacity and transient soft lift.
class BravaisCoverShadow {
  const BravaisCoverShadow(this.offset, this.color);
  static const none = BravaisCoverShadow(0, Color(0x00000000));
  final double offset;
  final Color color;
  BravaisCoverShadow atScale(double measuredWidth, double layoutWidth) =>
      BravaisCoverShadow(
        offset * (layoutWidth != 0 ? measuredWidth / layoutWidth : 1),
        color,
      );
}

enum BravaisCoverLanding { swap, fade }

class BravaisCoverFlightFrame {
  const BravaisCoverFlightFrame({
    required this.quad,
    required this.scale,
    required this.hard,
    required this.softOffset,
    required this.softBlur,
    required this.softAlpha,
    this.opacity = 1,
  });
  final BravaisCoverQuad quad;
  final double scale, softBlur, softAlpha, opacity;
  final Offset softOffset;
  final BravaisCoverShadow hard;
  BravaisCoverFlightFrame withOpacity(double value) => BravaisCoverFlightFrame(
    quad: quad,
    scale: scale,
    hard: hard,
    softOffset: softOffset,
    softBlur: softBlur,
    softAlpha: softAlpha,
    opacity: value,
  );
  static BravaisCoverFlightFrame sample(
    BravaisCoverQuad quad,
    BravaisCoverShadow from,
    BravaisCoverShadow to,
    double t,
  ) {
    final lift = math.sin(math.pi * t),
        color = t < .5 ? from.color : to.color,
        alpha = ((t < .5 ? 1 - t * 2 : t * 2 - 1) * 100 + .5).floor() / 100;
    return BravaisCoverFlightFrame(
      quad: quad,
      scale: 1 + lift * .05,
      hard: BravaisCoverShadow(
        from.offset + (to.offset - from.offset) * t,
        color.withValues(alpha: color.a * alpha),
      ),
      softOffset: Offset(lift * 10, lift * 16),
      softBlur: lift * 30,
      softAlpha: double.parse((lift * .4).toStringAsFixed(3)),
    );
  }
}

double bravaisCoverEase(double t) =>
    t < .5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;

class BravaisCoverFlight extends ChangeNotifier
    implements ValueListenable<double> {
  BravaisCoverFlight({
    required this.url,
    required this.from,
    required this.target,
    required this.startedAt,
    required this.duration,
    required this.shadowFrom,
    required this.shadowTo,
    required this.landing,
    required this.onFinish,
    this.ready,
    this.lost,
    this.onDone,
  }) : _last = from {
    frame = BravaisCoverFlightFrame.sample(from, shadowFrom, shadowFrom, 0);
  }
  final String url;
  final BravaisCoverQuad from;
  final BravaisCoverQuad? Function() target;
  final double startedAt, duration;
  final BravaisCoverShadow shadowFrom;
  final BravaisCoverShadow Function(BravaisCoverQuad) shadowTo;
  final BravaisCoverLanding landing;
  final bool Function()? ready, lost;
  final VoidCallback? onDone;
  final void Function(BravaisCoverFlight) onFinish;
  late BravaisCoverFlightFrame frame;
  BravaisCoverQuad _last;
  double? _fadeStart, _fadeDuration;
  int? _removeTick;
  bool _finished = false, _removed = false;
  bool get removed => _removed;
  @override
  double get value => frame.opacity;
  void step(double now, int tick) {
    if (_removed) return;
    final removeTick = _removeTick;
    if (removeTick != null && tick >= removeTick) {
      _removed = true;
      return;
    }
    final fadeStart = _fadeStart;
    if (fadeStart != null) {
      final t = ((now - fadeStart) / _fadeDuration!).clamp(0.0, 1.0);
      frame = frame.withOpacity(1 - cssBezier(0, 0, .58, 1, t));
      if (t >= 1) _removed = true;
      notifyListeners();
      return;
    }
    if (_finished) return;
    if (lost?.call() ?? false) {
      _finished = true;
      _fadeStart = now;
      _fadeDuration = 150;
      return;
    }
    final elapsed = now - startedAt,
        t = math.min(1.0, elapsed / duration),
        to = target() ?? _last,
        p = bravaisCoverEase(t);
    _last = to;
    frame = BravaisCoverFlightFrame.sample(
      BravaisCoverQuad.lerp(from, to, p),
      shadowFrom,
      shadowTo(to),
      p,
    );
    // The executable original uses +600ms, despite its nearby comment saying 400.
    final waiting = ready != null && !ready!() && elapsed < duration + 600;
    notifyListeners();
    if (t >= 1 && !waiting) finish(now, tick);
  }

  void finish(double now, int tick) {
    if (_finished || _removed) return;
    _finished = true;
    try {
      onDone?.call();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Folia cover flight',
          context: ErrorDescription('while handing off the original cover'),
        ),
      );
    }
    if (landing == BravaisCoverLanding.fade) {
      _fadeStart = now;
      _fadeDuration = 200;
    } else {
      _removeTick = tick + 1;
    }
    onFinish(this);
  }
}
