import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../wall_pan_motion.dart';
import '../wall_types.dart';
import 'wall_pointer_pan.dart';

// Native raw pointers bypass Flutter's pan gesture-arena threshold; controls still own seeking/editing and keep their original exclusion rules.
class WallInputRegion extends StatefulWidget {
  const WallInputRegion({
    super.key,
    required this.pan,
    required this.child,
    this.onDown,
    this.onUp,
    this.onCancel,
    this.onMove,
    this.active = true,
  });
  final WallPointerPan pan;
  final Widget child;
  final ValueChanged<WallPointerSample>? onDown, onUp, onCancel, onMove;
  final bool active;
  @override
  State<WallInputRegion> createState() => _WallInputRegionState();
}

class _WallInputRegionState extends State<WallInputRegion>
    with WidgetsBindingObserver {
  final _pointers = <int>{};
  final _touches = <int>{};
  bool _foreground = true;
  Offset? _origin;
  int? _primaryTouch;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.pan.setActive(widget.active && _foreground);
  }

  @override
  void didUpdateWidget(WallInputRegion old) {
    super.didUpdateWidget(old);
    if (old.pan != widget.pan) old.pan.cancel();
    widget.pan.setActive(widget.active && _foreground);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    widget.pan.setActive(widget.active && _foreground);
    if (!_foreground) _clear();
  }

  @override
  void didChangeMetrics() {
    widget.pan.cancel();
    _clear();
  }

  void _clear() {
    _pointers.clear();
    _touches.clear();
    _primaryTouch = null;
    _origin = null;
  }

  WallPointerSample _sample(
    PointerEvent event, {
    bool control = false,
    bool editable = false,
  }) {
    final local =
            event.position -
            (_origin ?? (event.position - event.localPosition)),
        touch = event.kind == PointerDeviceKind.touch;
    return WallPointerSample(
      event.pointer,
      local.dx,
      local.dy,
      event.timeStamp.inMicroseconds / 1000,
      touch: touch,
      primary: !touch || _primaryTouch == event.pointer,
      button: event is PointerDownEvent && (event.buttons & kPrimaryButton) == 0
          ? 1
          : 0,
      control: control,
      editable: editable,
    );
  }

  void _down(PointerDownEvent event) {
    if (_pointers.isEmpty) _origin = event.position - event.localPosition;
    _pointers.add(event.pointer);
    if (event.kind == PointerDeviceKind.touch) {
      if (_touches.isEmpty) _primaryTouch = event.pointer;
      _touches.add(event.pointer);
    }
    final excluded = _wallControls[event.original ?? event],
        sample = _sample(
          event,
          control: excluded == WallInputControl.control,
          editable: excluded == WallInputControl.editable,
        );
    (widget.onDown ?? widget.pan.pointerDown)(sample);
  }

  void _end(PointerEvent event, bool cancelled) {
    final sample = _sample(event);
    if (cancelled) {
      (widget.onCancel ?? widget.pan.pointerCancel)(sample);
    } else {
      (widget.onUp ?? widget.pan.pointerUp)(sample);
    }
    _pointers.remove(event.pointer);
    _touches.remove(event.pointer);
    if (_touches.isEmpty) _primaryTouch = null;
    if (_pointers.isEmpty) _origin = null;
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onKeyEvent: (_, event) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        final key = event.logicalKey;
        if (![
          LogicalKeyboardKey.shiftLeft,
          LogicalKeyboardKey.shiftRight,
          LogicalKeyboardKey.controlLeft,
          LogicalKeyboardKey.controlRight,
          LogicalKeyboardKey.altLeft,
          LogicalKeyboardKey.altRight,
          LogicalKeyboardKey.metaLeft,
          LogicalKeyboardKey.metaRight,
        ].contains(key)) {
          widget.pan.cancel();
        }
      }
      return KeyEventResult.ignored;
    },
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: (event) =>
          (widget.onMove ?? widget.pan.pointerMove)(_sample(event)),
      onPointerUp: (event) => _end(event, false),
      onPointerCancel: (event) => _end(event, true),
      onPointerHover: (event) => widget.pan.hoverPointer(
        WallPoint(event.localPosition.dx, event.localPosition.dy),
      ),
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent ||
            HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed) {
          return;
        }
        GestureBinding.instance.pointerSignalResolver.register(event, (
          resolved,
        ) {
          final wheel = resolved as PointerScrollEvent,
              keys = HardwareKeyboard.instance;
          widget.pan.wheel(
            WallWheelSample(
              wheel.scrollDelta.dx,
              wheel.scrollDelta.dy,
              wheel.timeStamp.inMicroseconds / 1000,
              shift: keys.isShiftPressed,
            ),
            ctrl: keys.isControlPressed,
            meta: keys.isMetaPressed,
            pointer: WallPoint(wheel.localPosition.dx, wheel.localPosition.dy),
          );
        });
      },
      child: widget.child,
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.pan.cancel(commitScale: false);
    super.dispose();
  }
}

enum WallInputControl { control, editable }

// Event-keyed weak storage exists only during pointer dispatch; leaf controls mark the same event before the wall ancestor sees it.
final _wallControls = Expando<WallInputControl>();

class WallControlRegion extends StatelessWidget {
  const WallControlRegion({
    super.key,
    required this.child,
    this.editable = false,
  });
  final Widget child;
  final bool editable;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      if (_wallControls[event.original ?? event] != WallInputControl.control) {
        _wallControls[event.original ?? event] = editable
            ? WallInputControl.editable
            : WallInputControl.control;
      }
    },
    child: child,
  );
}
