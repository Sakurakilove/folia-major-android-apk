import 'package:flutter/widgets.dart';

import '../motion/motion_curves.dart';
import '../motion/spring_options.dart';
import '../motion/value_options.dart';
import '../motion/physical_simulation.dart';

// The source translation entry has no explicit transition: opacity uses Motion's default ease, y uses its default physical spring.
class SubtitleTranslationEntry extends StatefulWidget {
  const SubtitleTranslationEntry({super.key, required this.child});
  final Widget child;
  @override
  State<SubtitleTranslationEntry> createState() =>
      _SubtitleTranslationEntryState();
}

class _SubtitleTranslationEntryState extends State<SubtitleTranslationEntry>
    with TickerProviderStateMixin {
  late final _opacityOptions = resolveMotionValueOptions('opacity', [
    0.0,
    1.0,
  ], const {});
  late final _positionOptions = resolveMotionValueOptions('y', [
    10.0,
    0.0,
  ], const {});
  late final _opacity = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: (_opacityOptions['duration'] as num).toInt(),
    ),
  );
  late final _position = AnimationController.unbounded(vsync: this, value: 10);
  late final _frames = Listenable.merge([_opacity, _position]);
  late final _spring = resolveMotionSpring(_positionOptions).between(10, 0);
  late final _points = (_opacityOptions['ease'] as List)
      .map((n) => (n as num).toDouble())
      .toList(growable: false);
  late final _ease = CssBezierCurve(
    _points[0],
    _points[1],
    _points[2],
    _points[3],
  );
  @override
  void initState() {
    super.initState();
    _opacity.forward();
    _position.animateWith(MotionSpringSimulation(_spring));
  }

  @override
  void dispose() {
    _opacity.dispose();
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _frames,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _ease.transform(_opacity.value),
      child: Transform.translate(
        offset: Offset(0, _position.value),
        child: child,
      ),
    ),
  );
}
