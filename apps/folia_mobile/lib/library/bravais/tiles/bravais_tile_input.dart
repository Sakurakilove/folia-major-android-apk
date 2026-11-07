import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../wall/input/wall_input_region.dart';
import 'bravais_item.dart';
import 'focus/bravais_focus_actions.dart';

part 'input/bravais_tile_input_layer.dart';

// One history belongs to the complete wall host. Mouse annotation updates precede pointer routing, so a stationary camera-induced enter sees the previous actual position.
class BravaisPointerHistory {
  Offset? _last;
  bool _attached = false;
  void attach() {
    if (_attached) return;
    _attached = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_record);
  }

  void _record(PointerEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        (event is PointerHoverEvent || event is PointerMoveEvent)) {
      _last = event.position;
    }
  }

  bool stayed(Offset position) => _last == position;
  void dispose() {
    if (!_attached) return;
    _attached = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_record);
    _last = null;
  }
}

class BravaisTileInput extends StatefulWidget {
  const BravaisTileInput({
    super.key,
    required this.slotKey,
    required this.face,
    required this.expanded,
    required this.actions,
    required this.pointerHistory,
    required this.consumeDrag,
    required this.noteAlbumSource,
    required this.onHover,
    required this.child,
  });
  final String slotKey;
  final BravaisCardFace face;
  final bool expanded;
  final BravaisCardActions actions;
  final BravaisPointerHistory pointerHistory;
  final bool Function() consumeDrag;
  final void Function(BuildContext tile, BravaisItem item) noteAlbumSource;
  final ValueChanged<bool> onHover;
  final Widget child;
  @override
  State<BravaisTileInput> createState() => _BravaisTileInputState();
}

class _BravaisTileInputState extends State<BravaisTileInput> {
  bool _control = false;
  void _activate() {
    final w = widget;
    // The original checks button descendants before consuming the residual drag click.
    if (_control || w.consumeDrag()) return;
    final item = w.face.item;
    if (item?.kind == BravaisItemKind.album) w.noteAlbumSource(context, item!);
    w.actions.activate(w.slotKey);
  }

  void _semanticActivate() {
    final w = widget, item = w.face.item;
    if (item?.kind == BravaisItemKind.album) w.noteAlbumSource(context, item!);
    w.actions.activate(w.slotKey);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget,
        item = w.face.item,
        actionable = item != null && w.face.kind != BravaisTileKind.heading;
    return _BravaisInputLayer(
      onEnter: (event) {
        w.onHover(true);
        if (!w.pointerHistory.stayed(event.position)) {
          w.actions.hover(w.slotKey);
        }
      },
      onExit: (_) {
        w.onHover(false);
        w.actions.hover(null);
      },
      onDown: (event) => _control = wallInputControlOf(event) != null,
      onTap: _activate,
      semanticTap: actionable ? _semanticActivate : null,
      label: item?.accessibleName,
      button: actionable && !w.expanded,
      expanded: item?.kind == BravaisItemKind.track ? w.expanded : null,
      textDirection: Directionality.maybeOf(context),
      child: w.child,
    );
  }
}
