import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

// Original continuous 9-second chaotic keyframes and 800ms return; a track change does not restart this widget.
class MonetPortraitDrift extends StatefulWidget {
  const MonetPortraitDrift({
    super.key,
    required this.chaotic,
    required this.child,
  });
  final bool chaotic;
  final Widget child;
  @override
  State<MonetPortraitDrift> createState() => _MonetPortraitDriftState();
}

class _MonetPortraitDriftState extends State<MonetPortraitDrift>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );
  Timer? _delay;
  Offset _returnOffset = Offset.zero;
  double _returnAngle = 0;
  static const _ease = Cubic(.42, 0, .58, 1), _out = Cubic(0, 0, .58, 1);
  static const _x = [0.0, -9.0, 0.0, 9.0, 0.0],
      _y = [0.0, -18.0, 0.0, 18.0, 0.0],
      _turn = [0.0, 1.2, 0.0, -1.2, 0.0];
  ({Offset offset, double angle}) _pose(bool chaotic) {
    if (!chaotic) {
      final remaining = 1 - _out.transform(_clock.value);
      return (
        offset: _returnOffset * remaining,
        angle: _returnAngle * remaining,
      );
    }
    final phase = _clock.value * 4,
        i = math.min(3, phase.floor()),
        t = _ease.transform(phase - i);
    double lerp(List<double> values) =>
        values[i] + (values[i + 1] - values[i]) * t;
    return (
      offset: Offset(lerp(_x), lerp(_y)),
      angle: lerp(_turn) * math.pi / 180,
    );
  }

  void _start() {
    _delay?.cancel();
    _clock.stop();
    if (widget.chaotic) {
      _clock.duration = const Duration(seconds: 9);
      _clock.value = 0;
      _delay = Timer(const Duration(milliseconds: 200), () {
        if (mounted) _clock.repeat();
      });
    } else {
      _clock.duration = const Duration(milliseconds: 800);
      _clock.forward(from: 0);
    }
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(MonetPortraitDrift old) {
    super.didUpdateWidget(old);
    if (old.chaotic != widget.chaotic) {
      final pose = _pose(old.chaotic);
      _returnOffset = pose.offset;
      _returnAngle = pose.angle;
      _start();
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    child: widget.child,
    builder: (context, child) {
      final pose = _pose(widget.chaotic);
      return Transform.translate(
        offset: pose.offset,
        child: Transform.rotate(angle: pose.angle, child: child),
      );
    },
  );
}
