part of 'bravais_wall_scene.dart';

// Cull/display/focus notifications are discrete; neither frame.value nor reflow.value is a widget-build subscription.
extension _BravaisWallSceneLogic on _BravaisWallSceneState {
  Widget _buildPlane() {
    final w = widget, display = w.display.value, selection = w.selection.value;
    _prepare(display, selection);
    return IgnorePointer(
      ignoring: !_active || !w.interactive,
      child: WallInputRegion(
        pan: w.camera.pointer,
        active: _active && w.interactive,
        onDown: w.camera.pointerDown,
        onMove: w.camera.pointerMove,
        onUp: w.camera.pointerUp,
        onCancel: w.camera.pointerCancel,
        child: BravaisWallView(
          slots: _slots,
          display: display,
          frame: w.camera.frame,
          dpr: w.dpr,
          committedScale: w.committedScale,
          viewportWidth: w.camera.view.width,
          resources: _cardResources,
          actions: w.actions,
          pointerHistory: _pointerHistory,
          consumeDrag: () => w.camera.pointer.consumeClick(),
          noteAlbumSource: w.noteAlbumSource,
          palette: w.palette,
          plates: w.backdropOpen ? _platePainter : null,
          reflow: _reflow,
          targetReflow: _targetReflow,
          expandedSlotKey: selection.expandedSlotKey,
          focusedSlotKey: selection.focusedSlotKey,
          linkedKey: selection.linkedKey,
          lightsOut: w.lightsOut,
          tinted: w.tinted,
          stackEdges: w.stackEdges,
          posterWall: w.posterWall,
          posterTint: w.posterTint,
          reducedMotion: w.reducedMotion,
          reducedTransitions: w.reducedTransitions,
          managingHidden: w.managingHidden,
          entersLattice: w.entersLattice,
          active: _active,
          interactive: w.interactive,
          android: w.android,
        ),
      ),
    );
  }

  void _listen(BravaisWallScene source, bool listen) {
    for (final signal in [
      source.camera.cull,
      source.camera.anchorSignal,
      source.display,
      source.selection,
    ]) {
      if (listen) {
        signal.addListener(_changed);
      } else {
        signal.removeListener(_changed);
      }
    }
  }

  void _syncActive() {
    _clockDomain.setActive(_active);
    widget.camera.setActive(_active);
    widget.camera.pointer.setActive(_active && widget.interactive);
    _reflow.setActive(_active);
  }

  void _prepare(BravaisDisplay? display, BravaisWallSelection selection) {
    final camera = widget.camera,
        bounds = camera.cull.value,
        shape = display?.shape ?? bravaisBlockShape;
    if (!identical(shape, _lastShape) || !identical(bounds, _lastBounds)) {
      _slots = stableBravaisSlots(
        bounds == null
            ? []
            : collectShapeSlots(
                shape,
                WallBounds(
                  bounds.left - 300,
                  bounds.right + 300,
                  bounds.top - 300,
                  bounds.bottom + 300,
                ),
                limit: 400,
                visible: bounds,
              ),
        _slots,
      );
      _lastShape = shape;
      _lastBounds = bounds;
    }
    if (_expanded != selection.expandedSlotKey ||
        !identical(_reflowShape, shape)) {
      _expanded = selection.expandedSlotKey;
      _reflowShape = shape;
      _targetReflow = {
        for (final e
            in (widget.focusReflow?.call(_expanded, shape) ??
                    resolveFocusReflow(_expanded, shape: shape))
                .entries)
          e.key: WallRect(e.value.x, e.value.y, e.value.width, e.value.height),
      };
      _reflow.updateTargets(_targetReflow, enabled: !widget.reducedMotion);
    }
    final plates = _plateCache.update(
      enabled: widget.backdropOpen,
      slots: _slots,
      display: display,
      expandedSlotKey: selection.expandedSlotKey,
      reflow: _targetReflow,
      anchorX: camera.anchorX,
    );
    if (!identical(plates, _lastPlates) ||
        _lastPaper != widget.palette.background) {
      _lastPlates = plates;
      _lastPaper = widget.palette.background;
      _platePainter.update(
        plates.left,
        plates.right,
        widget.palette.background,
      );
    }
  }
}
