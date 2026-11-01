import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../visualizer/motion/motion_curves.dart';
import '../../visualizer/motion/keyframes.dart';

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
  static const _out = MotionBezierCurve(0, 0, .58, 1);
  static final _x = MotionKeyframes([0, -9, 0, 9, 0], duration: 9000),
      _y = MotionKeyframes([0, -18, 0, 18, 0], duration: 9000),
      _turn = MotionKeyframes([0, 1.2, 0, -1.2, 0], duration: 9000);
  ({Offset offset, double angle}) _pose(bool chaotic) {
    if (!chaotic) {
      final remaining = 1 - _out.transform(_clock.value);
      return (
        offset: _returnOffset * remaining,
        angle: _returnAngle * remaining,
      );
    }
    final time = _clock.value * 9000;
    return (
      offset: Offset(_x.x(time), _y.x(time)),
      angle: _turn.x(time) * math.pi / 180,
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
