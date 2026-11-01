import 'package:flutter/widgets.dart';

import '../../rendering/css_shadows.dart';

// Source hanger pulse, hover/press scale and 200ms return, confined to this 12x56 surface.
class MonetPortraitHanger extends StatefulWidget {
  const MonetPortraitHanger({
    super.key,
    required this.editing,
    required this.primary,
    required this.accent,
    required this.background,
    required this.onTap,
    required this.onDown,
    required this.onMove,
    required this.onEnd,
  });
  final bool editing;
  final Color primary, accent, background;
  final VoidCallback onTap;
  final void Function(PointerDownEvent) onDown;
  final void Function(PointerMoveEvent) onMove;
  final void Function(PointerEvent) onEnd;
  @override
  State<MonetPortraitHanger> createState() => _MonetPortraitHangerState();
}

class _MonetPortraitHangerState extends State<MonetPortraitHanger>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _hovered = false, _pressed = false;
  Color? _startBorder;
  double _startRadius = 0, _startAlpha = 0;
  static const _ease = Cubic(.42, 0, .58, 1);
  ({Color border, double radius, double alpha}) _style(bool editing) {
    if (editing) {
      final phase = _clock.value * 2;
      final pulse = _ease.transform(phase <= 1 ? phase : 2 - phase);
      return (
        border: widget.accent.withValues(alpha: .3 + .7 * pulse),
        radius: 2 + 8 * pulse,
        alpha: .2 + .45 * pulse,
      );
    }
    final end = widget.primary.withValues(alpha: _hovered ? .36 : 0),
        t = _ease.transform(_clock.value);
    return (
      border: Color.lerp(_startBorder ?? end, end, t)!,
      radius: _startRadius * (1 - t),
      alpha: _startAlpha * (1 - t),
    );
  }

  void _animate(bool wasEditing) {
    final previous = _style(wasEditing);
    _startBorder = previous.border;
    _startRadius = previous.radius;
    _startAlpha = previous.alpha;
    _clock.stop();
    if (widget.editing) {
      _clock.duration = const Duration(milliseconds: 1500);
      _clock.value = 0;
      _clock.repeat();
    } else {
      _clock.duration = const Duration(milliseconds: 200);
      _clock.forward(from: 0);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.editing) {
      _clock.repeat();
    } else {
      _clock.value = 1;
    }
  }

  @override
  void didUpdateWidget(MonetPortraitHanger old) {
    super.didUpdateWidget(old);
    if (old.editing != widget.editing) _animate(old.editing);
  }

  void _hover(bool value) {
    final previous = _style(widget.editing);
    setState(() {
      _hovered = value;
    });
    if (!widget.editing) {
      _startBorder = previous.border;
      _startRadius = previous.radius;
      _startAlpha = previous.alpha;
      _clock.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => _hover(true),
    onExit: (_) => _hover(false),
    child: Listener(
      onPointerDown: (event) {
        setState(() {
          _pressed = true;
        });
        widget.onDown(event);
      },
      onPointerMove: widget.onMove,
      onPointerUp: (event) {
        setState(() {
          _pressed = false;
        });
        widget.onEnd(event);
      },
      onPointerCancel: (event) {
        setState(() {
          _pressed = false;
        });
        widget.onEnd(event);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: 1,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: const Cubic(.4, 0, .2, 1),
            transformAlignment: Alignment.center,
            transform: Matrix4.diagonal3Values(
              1,
              _pressed
                  ? .95
                  : _hovered
                  ? 1.05
                  : 1,
              1,
            ),
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) {
                final style = _style(widget.editing);
                return Container(
                  width: 12,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: widget.background.withValues(alpha: .86),
                    border: Border.all(color: style.border, width: 1.5),
                    boxShadow: [
                      if (style.radius > 0)
                        cssBoxShadow(
                          widget.accent.withValues(alpha: style.alpha),
                          Offset.zero,
                          style.radius,
                        ),
                      cssBoxShadow(
                        const Color(0xff000000).withValues(alpha: .24),
                        const Offset(0, 8),
                        18,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
