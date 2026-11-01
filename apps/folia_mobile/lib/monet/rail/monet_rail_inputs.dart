part of 'monet_rail.dart';

// Inputs logic stays outside the rail widget assembly.
extension _MonetRailInputs on _MonetRailState {
  void _scheduleReset() {
    _manualReset?.cancel();
    _manualReset = Timer(
      const Duration(milliseconds: monetScrollIdleResetMs),
      () {
        if (!mounted) return;
        _manualAnchor = null;
        _wheelAccum = 0;
        _wheelDirection = 0;
        _touchAccum = 0;
        _touchDirection = 0;
        _sync(force: true);
        _repaint.invalidate();
      },
    );
  }

  int _fallbackAnchor() =>
      _manualAnchor ??
      (_currentIndex >= 0
          ? _currentIndex
          : _ordered
                    .where((r) => r.motion.entry.entry.offset == 0)
                    .firstOrNull
                    ?.motion
                    .entry
                    .entry
                    .index ??
                0);
  void _moveAnchor(int steps) {
    if (widget.document.lines.isEmpty) return;
    _manualAnchor = (_fallbackAnchor() + steps.clamp(-1, 1)).clamp(
      0,
      widget.document.lines.length - 1,
    );
    _scheduleReset();
    _sync(force: true);
    _repaint.invalidate();
  }

  void _pointerDown(PointerDownEvent event) {
    if (widget.document.lines.isEmpty || _pointer != null) return;
    _pointer = event.pointer;
    _touchLastY = event.localPosition.dy;
    _touchAccum = 0;
    _touchDirection = 0;
    _manualAnchor = _fallbackAnchor();
    _scheduleReset();
    _sync(force: true);
  }

  void _pointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer || _touchLastY == null) return;
    final delta = _touchLastY! - event.localPosition.dy;
    _touchLastY = event.localPosition.dy;
    final direction = delta.sign.toInt();
    if (direction != 0 &&
        _touchDirection != 0 &&
        direction != _touchDirection) {
      _touchAccum = 0;
    }
    if (direction != 0) _touchDirection = direction;
    _touchAccum += delta;
    final steps = (_touchAccum / monetTouchStepPx).truncate().clamp(-1, 1);
    if (steps != 0) {
      _touchAccum = 0;
      _moveAnchor(steps);
    } else {
      _scheduleReset();
    }
  }

  void _pointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _touchLastY = null;
    _touchAccum = 0;
    _touchDirection = 0;
    _scheduleReset();
  }

  void _wheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || widget.document.lines.isEmpty) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final delta = (event as PointerScrollEvent).scrollDelta.dy,
          direction = delta.sign.toInt();
      if (direction != 0 &&
          _wheelDirection != 0 &&
          direction != _wheelDirection) {
        _wheelAccum = 0;
      }
      if (direction != 0) _wheelDirection = direction;
      _wheelAccum += delta;
      final steps = (_wheelAccum / monetScrollStepPx).truncate().clamp(-1, 1);
      if (steps != 0) {
        _wheelAccum = 0;
        _moveAnchor(steps);
      } else {
        _scheduleReset();
      }
    });
  }

  void _seek(Offset local) {
    if (!_canSeek) return;
    final now = widget.seconds();
    for (final row in _ordered.reversed) {
      if (row.motion.exiting) continue;
      final rect = Rect.fromLTWH(
        _glow,
        row.motion.y(now),
        math.max(0, _size.width - _glow * 2) * row.motion.scale(now),
        row.motion.entry.layout.visualHeightPx * row.motion.scale(now),
      );
      if (rect.contains(local)) {
        widget.onLineSeek!(row.motion.entry.entry.line.start);
        _manualAnchor = null;
        _manualReset?.cancel();
        _sync(force: true);
        return;
      }
    }
  }
}
