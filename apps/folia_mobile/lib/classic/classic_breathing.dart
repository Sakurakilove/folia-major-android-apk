import 'package:flutter/widgets.dart';

// The original whole-line breathing track is independent of word events; child glyph/layout work stays out of its frame callback.
class ClassicBreathing extends StatefulWidget {
  const ClassicBreathing({
    super.key,
    required this.intensity,
    required this.multiplier,
    required this.child,
  });
  final String intensity;
  final double multiplier;
  final Widget child;
  @override
  State<ClassicBreathing> createState() => _ClassicBreathingState();
}

class _ClassicBreathingState extends State<ClassicBreathing>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this);
  static const _ease = Cubic(.42, 0, .58, 1);
  late List<double> _offsets, _scales;
  @override
  void initState() {
    super.initState();
    _configure();
  }

  @override
  void didUpdateWidget(ClassicBreathing old) {
    super.didUpdateWidget(old);
    if (old.intensity != widget.intensity ||
        old.multiplier != widget.multiplier) {
      _configure();
    }
  }

  void _configure() {
    final (distance, milliseconds) = switch (widget.intensity) {
      'calm' => (10.0, 8500),
      'chaotic' => (18.0, 5800),
      _ => (14.0, 7000),
    };
    final span = distance * widget.multiplier;
    _offsets = [0, -span, 0, span * .45, 0];
    _scales = [
      1,
      1 + .01 * widget.multiplier,
      1,
      1 - .005 * widget.multiplier,
      1,
    ];
    _clock.stop();
    _clock.duration = Duration(milliseconds: milliseconds);
    _clock.value = 0;
    if (widget.multiplier > 0) _clock.repeat();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    child: widget.child,
    builder: (context, child) {
      if (widget.multiplier <= 0) return child!;
      final phase = _clock.value * 4,
          segment = phase.floor().clamp(0, 3),
          t = _ease.transform(phase - segment);
      final offset =
              _offsets[segment] +
              (_offsets[segment + 1] - _offsets[segment]) * t,
          size =
              _scales[segment] + (_scales[segment + 1] - _scales[segment]) * t;
      return Transform.translate(
        offset: Offset(0, offset),
        child: Transform.scale(scale: size, child: child),
      );
    },
  );
}
