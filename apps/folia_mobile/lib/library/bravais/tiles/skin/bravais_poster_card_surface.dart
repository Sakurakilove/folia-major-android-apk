import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../visualizer/motion/css_transition.dart';
import '../bravais_card_look.dart';

// The artist-wall ::after belongs to the fixed outer tile, above the rotating face. Its 260ms color-blend opacity is not disabled by lattice's reduction selectors.
class BravaisPosterCardSurface extends StatefulWidget {
  const BravaisPosterCardSurface({
    super.key,
    required this.look,
    required this.tint,
    required this.frames,
    required this.nowMs,
    required this.child,
    this.active = true,
  });
  final BravaisCardLook look;
  final Color tint;
  final Listenable frames;
  final double Function() nowMs;
  final Widget child;
  final bool active;
  @override
  State<BravaisPosterCardSurface> createState() =>
      _BravaisPosterCardSurfaceState();
}

class _BravaisPosterCardSurfaceState extends State<BravaisPosterCardSurface> {
  late final CssNumericSignal _opacity;
  bool _tickerEnabled = true;
  @override
  void initState() {
    super.initState();
    _opacity = CssNumericSignal(
      widget.look.posterTintOpacity,
      frames: widget.frames,
      nowMs: widget.nowMs,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _opacity.setActive(widget.active && _tickerEnabled);
  }

  @override
  void didUpdateWidget(BravaisPosterCardSurface old) {
    super.didUpdateWidget(old);
    _opacity.nowMs = widget.nowMs;
    _opacity.rebindFrames(widget.frames);
    _opacity.setActive(widget.active && _tickerEnabled);
    _opacity.setTarget(
      widget.look.posterTintOpacity,
      const CssTransitionSpec(260),
      enabled:
          widget.look.posterWall &&
          old.look.posterWall == widget.look.posterWall,
    );
  }

  @override
  Widget build(BuildContext context) => _PosterTintLayer(
    opacity: _opacity,
    color: widget.tint,
    enabled: widget.look.posterWall,
    child: widget.child,
  );
  @override
  void dispose() {
    _opacity.dispose();
    super.dispose();
  }
}

class _PosterTintLayer extends SingleChildRenderObjectWidget {
  const _PosterTintLayer({
    required this.opacity,
    required this.color,
    required this.enabled,
    super.child,
  });
  final ValueListenable<double> opacity;
  final Color color;
  final bool enabled;
  @override
  RenderBravaisPosterTint createRenderObject(BuildContext context) =>
      RenderBravaisPosterTint(opacity, color, enabled);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderBravaisPosterTint renderObject,
  ) => renderObject.update(opacity, color, enabled);
}

class RenderBravaisPosterTint extends RenderProxyBox {
  RenderBravaisPosterTint(this._opacity, this._color, this._enabled);
  ValueListenable<double> _opacity;
  Color _color;
  bool _enabled;
  void update(ValueListenable<double> opacity, Color color, bool enabled) {
    if (!identical(opacity, _opacity)) {
      if (attached) _opacity.removeListener(markNeedsPaint);
      _opacity = opacity;
      if (attached) _opacity.addListener(markNeedsPaint);
    }
    if (_color != color || _enabled != enabled) {
      _color = color;
      _enabled = enabled;
      markNeedsPaint();
    }
  }

  @override
  Rect get paintBounds => child?.paintBounds ?? (Offset.zero & size);
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _opacity.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _opacity.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!_enabled || _opacity.value <= 0 || _color.a == 0) return;
    final rect = (offset & size).deflate(10);
    if (rect.isEmpty) return;
    context.canvas.drawRect(
      rect,
      Paint()
        ..color = _color.withValues(alpha: _color.a * _opacity.value)
        ..blendMode = BlendMode.color,
    );
  }
}
