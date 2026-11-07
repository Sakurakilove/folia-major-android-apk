part of 'bravais_viewport.dart';

// Sort only after materialization, focus or hover changes. Camera and reflow frames reuse the same stable CSS stacking order.
extension _BravaisViewportOrder on RenderBravaisViewport {
  List<RenderBox> get _paintOrder {
    if (_ordered != null) return _ordered!;
    final indexed = <({RenderBox child, int order})>[];
    var child = firstChild;
    while (child != null) {
      indexed.add((child: child, order: indexed.length));
      child = (child.parentData! as BravaisSeatData).nextSibling;
    }
    indexed.sort((a, b) {
      final z = (a.child.parentData! as BravaisSeatData).zIndex.compareTo(
        (b.child.parentData! as BravaisSeatData).zIndex,
      );
      return z == 0 ? a.order.compareTo(b.order) : z;
    });
    return _ordered = indexed
        .map((entry) => entry.child)
        .toList(growable: false);
  }
}
