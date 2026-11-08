import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../wall/reveal_rect.dart';
import '../../wall/wall_slots.dart';
import '../../wall/wall_types.dart';
import '../bravais_frame.dart';
import '../bravais_poster_reveal.dart';
import '../display/bravais_display_slots.dart';
import '../shape/bravais_wall_shape.dart';
import 'bravais_wall_selection.dart';

// Source refs change during the action; the memoized drawn rectangles change only when the wall commits its discrete selection. Expanding still reveals freshly resolved geometry immediately.
typedef BravaisFocusFrame = ({
  BravaisRevealFrame frame,
  double targetOpenWidth,
});

class BravaisFocusModel extends ValueNotifier<BravaisWallSelection> {
  BravaisFocusModel({
    required this.readFrame,
    required this.tweenTo,
    required this.getBottomInset,
    required this.onFocusEntry,
    required this.getShape,
  }) : super(const BravaisWallSelection());
  final BravaisFocusFrame? Function() readFrame;
  final void Function(WallPoint center) tweenTo;
  final double Function() getBottomInset;
  final void Function(String? slotKey) onFocusEntry;
  final BravaisWallShape Function() getShape;
  Map<String, WallSlot> _reflow = const {};
  String? _memoExpanded;
  bool _hasMemo = false, _closed = false;
  Map<String, WallSlot> reflowForBuild(
    String? expanded,
    BravaisWallShape shape,
  ) {
    if (_closed) return const {};
    if (!_hasMemo || _memoExpanded != expanded) {
      _hasMemo = true;
      _memoExpanded = expanded;
      _reflow = Map.unmodifiable(resolveFocusReflow(expanded, shape: shape));
    }
    return _reflow;
  }

  WallSlot drawnSlot(WallSlot slot) => _reflow[slot.key] ?? slot;
  void reveal(WallGeometry rect, {bool centered = false}) {
    if (_closed) return;
    final current = readFrame();
    if (current == null) return;
    final frame = current.frame,
        width = math.max(frame.openWidth, current.targetOpenWidth);
    tweenTo(
      frame.poster
          ? resolveBravaisPosterRevealCenter(
              rect: rect,
              frame: frame,
              posterWidth: width,
              pad: 24,
              bottomInset: getBottomInset(),
            )
          : resolveWallRevealCenter(
              rect: rect,
              center: frame.center,
              view: frame.view,
              metrics: bravaisMetrics,
              anchorX: frame.anchorX,
              seamWidth: width,
              pad: 24,
              bottomInset: getBottomInset(),
              centered: centered,
            ),
    );
  }

  void focusSlot(WallSlot? slot, {bool revealSlot = false}) {
    if (_closed) return;
    final key = slot?.key;
    if (value.focusedSlotKey != key) {
      value = BravaisWallSelection(
        focusedSlotKey: key,
        expandedSlotKey: value.expandedSlotKey,
        linkedKey: value.linkedKey,
      );
      onFocusEntry(key);
    }
    if (slot != null && revealSlot) reveal(drawnSlot(slot));
  }

  void expand(WallSlot slot, {bool centered = false}) {
    if (_closed) return;
    value = BravaisWallSelection(
      focusedSlotKey: value.focusedSlotKey,
      expandedSlotKey: slot.key,
      linkedKey: value.linkedKey,
    );
    final rect = resolveFocusReflow(slot.key, shape: getShape())[slot.key];
    if (rect != null) reveal(rect, centered: centered);
  }

  void collapse() {
    if (_closed || value.expandedSlotKey == null) return;
    value = BravaisWallSelection(
      focusedSlotKey: value.focusedSlotKey,
      linkedKey: value.linkedKey,
    );
  }

  void setLinkedKey(String? key) {
    if (_closed) return;
    value = BravaisWallSelection(
      focusedSlotKey: value.focusedSlotKey,
      expandedSlotKey: value.expandedSlotKey,
      linkedKey: key,
    );
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _reflow = const {};
    super.dispose();
  }
}
