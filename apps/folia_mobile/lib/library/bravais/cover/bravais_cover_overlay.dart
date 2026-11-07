import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../artwork/wall_artwork_image.dart';
import '../../wall/wall_opacity.dart';
import 'bravais_cover_flight.dart';
import 'bravais_cover_flights.dart';

// Mount above the original app chrome, in the root viewport coordinate space. Only flight insertion/removal builds widgets; each image stream remains a retained native leaf.
class BravaisCoverOverlay extends StatelessWidget {
  const BravaisCoverOverlay({
    super.key,
    required this.flights,
    required this.imageFor,
  });
  final BravaisCoverFlights flights;
  // Resolve the original getSizedCoverUrl(url, 512) through the shared store.
  final ImageProvider<String>? Function(String url) imageFor;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: ValueListenableBuilder<bool>(
        valueListenable: flights.visibility,
        builder: (context, active, child) =>
            TickerMode(enabled: active, child: child!),
        child: ValueListenableBuilder(
          valueListenable: flights.entries,
          builder: (context, entries, _) => Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              for (final entry in entries)
                WallOpacity(
                  opacity: entry,
                  child: _CoverFlightLayer(
                    key: ObjectKey(entry),
                    flight: entry,
                    child: WallArtworkImage(provider: imageFor(entry.url)),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CoverFlightLayer extends SingleChildRenderObjectWidget {
  const _CoverFlightLayer({super.key, required this.flight, super.child});
  final BravaisCoverFlight flight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderBravaisCoverFlight(flight);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderBravaisCoverFlight renderObject,
  ) => renderObject.flight = flight;
}

class RenderBravaisCoverFlight extends RenderProxyBox {
  RenderBravaisCoverFlight(this._flight);
  BravaisCoverFlight _flight;
  final _background = Paint()..color = const Color(0xff222222),
      _hard = Paint(),
      _soft = Paint();
  final _transform = Matrix4.identity();
  final _transformLayer = LayerHandle<TransformLayer>();
  set flight(BravaisCoverFlight value) {
    if (identical(value, _flight)) return;
    if (attached) _flight.removeListener(_changed);
    _flight = value;
    if (attached) _flight.addListener(_changed);
    markNeedsLayout();
  }

  void _changed() {
    final quad = _flight.frame.quad;
    if (child?.hasSize != true ||
        child!.size != Size(quad.width, quad.height)) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  @override
  bool get isRepaintBoundary => true;
  @override
  bool get alwaysNeedsCompositing => child != null;
  @override
  bool get sizedByParent => true;
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;
  @override
  void performResize() => size = constraints.biggest;
  @override
  void performLayout() {
    final quad = _flight.frame.quad;
    child?.layout(BoxConstraints.tight(Size(quad.width, quad.height)));
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _flight.addListener(_changed);
  }

  @override
  void detach() {
    _flight.removeListener(_changed);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    final frame = _flight.frame,
        q = frame.quad,
        center = globalToLocal(q.center);
    _transform
      ..setIdentity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..rotateZ(q.angle)
      ..scaleByDouble(frame.scale, frame.scale, 1, 1)
      ..translateByDouble(-q.width / 2, -q.height / 2, 0, 1);
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) => _paintCover(context, offset, frame),
      oldLayer: _transformLayer.layer,
    );
  }

  void _paintCover(
    PaintingContext context,
    Offset offset,
    BravaisCoverFlightFrame frame,
  ) {
    final bounds = offset & child!.size,
        canvas = context.canvas,
        hard = frame.hard;
    // CSS paints shadow lists back-to-front; the hard ink shadow is on top.
    if (frame.softAlpha > 0) {
      _soft
        ..color = Color.from(alpha: frame.softAlpha, red: 0, green: 0, blue: 0)
        ..maskFilter = frame.softBlur > 0
            ? MaskFilter.blur(BlurStyle.normal, frame.softBlur / 2)
            : null;
      canvas.drawRect(bounds.shift(frame.softOffset), _soft);
    }
    if (hard.color.a > 0) {
      canvas.drawRect(
        bounds.shift(Offset(hard.offset, hard.offset)),
        _hard..color = hard.color,
      );
    }
    canvas.drawRect(bounds, _background);
    context.paintChild(child!, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => false;
  @override
  void dispose() {
    _transformLayer.layer = null;
    super.dispose();
  }
}
