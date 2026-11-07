import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// The original border-box body binds padding-bottom directly to the playback safe-area signal. Only layout changes, never a frame-valued widget rebuild.
class BravaisSeamBottomPadding extends SingleChildRenderObjectWidget {
  const BravaisSeamBottomPadding({
    super.key,
    required this.bottom,
    super.child,
  });
  final ValueListenable<double> bottom;
  @override
  RenderBravaisSeamBottomPadding createRenderObject(BuildContext context) =>
      RenderBravaisSeamBottomPadding(bottom);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderBravaisSeamBottomPadding renderObject,
  ) => renderObject.bottom = bottom;
}

class RenderBravaisSeamBottomPadding extends RenderPadding {
  RenderBravaisSeamBottomPadding(this._bottom)
    : super(padding: EdgeInsets.only(bottom: _bottom.value));
  ValueListenable<double> _bottom;
  set bottom(ValueListenable<double> next) {
    if (identical(next, _bottom)) return;
    if (attached) _bottom.removeListener(_changed);
    _bottom = next;
    if (attached) _bottom.addListener(_changed);
    _changed();
  }

  void _changed() => padding = EdgeInsets.only(bottom: _bottom.value);
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _bottom.addListener(_changed);
    _changed();
  }

  @override
  void detach() {
    _bottom.removeListener(_changed);
    super.detach();
  }
}
