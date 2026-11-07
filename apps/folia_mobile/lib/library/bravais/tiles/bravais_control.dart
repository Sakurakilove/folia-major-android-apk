import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../wall/input/wall_input_region.dart';
import '../../wall/wall_typography.dart';

// Plain source chrome: no Material ripple, padding minimums or replacement icons. Hover/focus only update the control, never the wall camera.
class BravaisControl extends StatefulWidget {
  const BravaisControl({
    super.key,
    required this.onPressed,
    required this.label,
    required this.builder,
    this.focusAccent,
    this.toggled,
    this.expanded,
    this.highlightLabel,
  });
  final VoidCallback? onPressed;
  final String label;
  final Widget Function(BuildContext, bool hovered, bool focused) builder;
  final Color? focusAccent;
  final bool? toggled, expanded;
  final String? highlightLabel;
  @override
  State<BravaisControl> createState() => _BravaisControlState();
}

class _BravaisControlState extends State<BravaisControl> {
  bool _hover = false, _focused = false;
  @override
  Widget build(BuildContext context) => WallControlRegion(
    child: Semantics(
      button: true,
      enabled: widget.onPressed != null,
      toggled: widget.toggled,
      expanded: widget.expanded,
      label: (_hover || _focused) && widget.onPressed != null
          ? widget.highlightLabel ?? widget.label
          : widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        enabled: widget.onPressed != null,
        mouseCursor: widget.onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: CustomPaint(
            foregroundPainter: _FocusRing(_focused ? widget.focusAccent : null),
            child: widget.builder(context, _hover, _focused),
          ),
        ),
      ),
    ),
  );
}

class _FocusRing extends CustomPainter {
  const _FocusRing(this.color);
  final Color? color;
  @override
  void paint(Canvas canvas, Size size) {
    if (color == null) return;
    canvas.drawRect(
      (Offset.zero & size).inflate(3),
      Paint()
        ..color = color!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_FocusRing old) => old.color != color;
}

class BravaisChromeButton extends StatelessWidget {
  const BravaisChromeButton({
    super.key,
    required this.ink,
    required this.accent,
    required this.typography,
    required this.label,
    required this.builder,
    required this.onPressed,
    this.iconOnly = false,
    this.minimumHeight = 44,
    this.horizontalPadding = 16,
    this.expanded,
    this.highlightLabel,
  });
  final Color ink, accent;
  final WallTypography typography;
  final String label;
  final VoidCallback? onPressed;
  final bool iconOnly;
  final bool? expanded;
  final String? highlightLabel;
  final double minimumHeight, horizontalPadding;
  final Widget Function(bool hoveredOrFocused) builder;
  @override
  Widget build(BuildContext context) => BravaisControl(
    label: label,
    highlightLabel: highlightLabel,
    onPressed: onPressed,
    expanded: expanded,
    focusAccent: accent,
    builder: (context, hover, focus) {
      final enabled = onPressed != null;
      return Opacity(
        opacity: enabled ? (iconOnly || hover ? 1 : .8) : .3,
        child: Container(
          width: iconOnly ? 44 : null,
          constraints: BoxConstraints(minHeight: minimumHeight),
          alignment: iconOnly ? Alignment.center : null,
          padding: EdgeInsets.symmetric(
            horizontal: iconOnly ? 0 : horizontalPadding,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hover && enabled
                  ? ink.withValues(alpha: ink.a * .26)
                  : const Color(0x00000000),
            ),
            color: hover && enabled
                ? ink.withValues(alpha: ink.a * .16)
                : const Color(0x00000000),
          ),
          child: DefaultTextStyle(
            style: typography.style(15, color: ink, weight: 700),
            child: builder(hover || focus),
          ),
        ),
      );
    },
  );
}
