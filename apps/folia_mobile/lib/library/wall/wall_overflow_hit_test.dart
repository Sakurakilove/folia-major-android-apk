import 'package:flutter/rendering.dart';

// CSS overflow-visible ancestors still route hits into transformed descendants. Only the descendant's real hit shape counts: shadows/paintBounds never expand an interactive region.
mixin WallOverflowHitTest on RenderBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    assert(hasSize);
    if (hitTestChildren(result, position: position) ||
        (size.contains(position) && hitTestSelf(position))) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}
