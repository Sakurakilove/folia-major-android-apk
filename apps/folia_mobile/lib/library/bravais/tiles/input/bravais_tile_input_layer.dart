part of '../bravais_tile_input.dart';

// Hover belongs to the fixed seat and its overflowing descendants; clicks belong only to the transformed article. One native node replaces box-clipped gesture/mouse/semantics wrappers.
class _BravaisInputLayer extends SingleChildRenderObjectWidget {
  const _BravaisInputLayer({
    required this.onEnter,
    required this.onExit,
    required this.onDown,
    required this.onTap,
    required this.semanticTap,
    required this.label,
    required this.button,
    required this.expanded,
    required this.textDirection,
    required super.child,
  });
  final PointerEnterEventListener onEnter;
  final PointerExitEventListener onExit;
  final ValueChanged<PointerDownEvent> onDown;
  final VoidCallback onTap;
  final VoidCallback? semanticTap;
  final String? label;
  final bool button;
  final bool? expanded;
  final TextDirection? textDirection;
  @override
  _RenderBravaisInput createRenderObject(BuildContext context) =>
      _RenderBravaisInput(this);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBravaisInput renderObject,
  ) => renderObject.update(this);
}

class _BravaisInputHit extends BoxHitTestEntry {
  _BravaisInputHit(super.target, super.localPosition, this.onFace);
  final bool onFace;
}

class _RenderBravaisInput extends RenderProxyBox
    implements MouseTrackerAnnotation {
  _RenderBravaisInput(this._data) {
    _tap = TapGestureRecognizer(debugOwner: this)..onTap = _data.onTap;
  }
  _BravaisInputLayer _data;
  late final TapGestureRecognizer _tap;
  void update(_BravaisInputLayer data) {
    _data = data;
    _tap.onTap = data.onTap;
    markNeedsSemanticsUpdate();
  }

  @override
  PointerEnterEventListener get onEnter => _data.onEnter;
  @override
  PointerExitEventListener get onExit => _data.onExit;
  @override
  MouseCursor get cursor => MouseCursor.defer;
  @override
  bool get validForMouseTracker => attached;
  @override
  Rect get paintBounds => child?.paintBounds ?? (Offset.zero & size);
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    assert(hasSize);
    // Bounds only reject distant candidates; the real child hit below excludes
    // every shadow. Avoid walking/inverting the full face tree for all 400 seats.
    if (!size.contains(position) &&
        !(child?.paintBounds.contains(position) ?? false)) {
      return false;
    }
    final face = hitTestChildren(result, position: position);
    if (face || size.contains(position)) {
      result.add(_BravaisInputHit(this, position, face));
      return true;
    }
    return false;
  }

  @override
  void handleEvent(PointerEvent event, covariant _BravaisInputHit entry) {
    if (event is PointerDownEvent) {
      _data.onDown(event);
      if (entry.onFace) _tap.addPointer(event);
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..isButton = _data.button
      ..isExpanded = _data.expanded
      ..label = _data.label ?? ''
      ..textDirection = _data.textDirection;
    final semanticTap = _data.semanticTap;
    if (semanticTap != null) config.onTap = semanticTap;
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }
}
