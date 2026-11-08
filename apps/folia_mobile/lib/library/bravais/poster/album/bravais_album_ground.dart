import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../wall/wall_typography.dart';
import '../bravais_album_composition.dart';
import 'bravais_album_entrance.dart';
import 'bravais_album_ground_program.dart';

// The real album ground belongs behind the safe-area UI, at the unscaled poster size. Its full paint bounds include the original static SVG grain outside the content box.
class BravaisAlbumGround extends StatefulWidget {
  const BravaisAlbumGround({
    super.key,
    required this.program,
    required this.composition,
    required this.entrance,
    required this.typography,
    required this.ghost,
    required this.dpr,
    this.colors = const BravaisAlbumGroundColors(),
  });
  final BravaisAlbumGroundProgram program;
  final BravaisAlbumComposition composition;
  final BravaisAlbumEntrance entrance;
  final WallTypography typography;
  final String ghost;
  final double dpr;
  final BravaisAlbumGroundColors colors;
  @override
  State<BravaisAlbumGround> createState() => _BravaisAlbumGroundState();
}

class _BravaisAlbumGroundState extends State<BravaisAlbumGround> {
  late BravaisAlbumGroundPainter _painter;
  bool _active = false;
  BravaisAlbumGroundPainter _create() => widget.program.create(
    composition: widget.composition,
    entrance: widget.entrance,
    typography: widget.typography,
    ghost: widget.ghost,
    dpr: widget.dpr,
    active: _active,
    colors: widget.colors,
  );
  @override
  void initState() {
    super.initState();
    _painter = _create();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _active = TickerMode.valuesOf(context).enabled;
    _painter.setActive(_active);
  }

  @override
  void didUpdateWidget(BravaisAlbumGround old) {
    super.didUpdateWidget(old);
    if (old.program != widget.program ||
        old.composition.divider != widget.composition.divider ||
        old.composition.ghostSide != widget.composition.ghostSide ||
        old.entrance != widget.entrance ||
        old.typography.fontsEpoch != widget.typography.fontsEpoch ||
        old.typography.locale != widget.typography.locale ||
        old.typography.direction != widget.typography.direction ||
        old.ghost != widget.ghost ||
        old.dpr != widget.dpr ||
        (old.colors.paper, old.colors.ink, old.colors.block) !=
            (widget.colors.paper, widget.colors.ink, widget.colors.block)) {
      _painter.dispose();
      _painter = _create();
    }
  }

  @override
  Widget build(BuildContext context) => _AlbumGroundLeaf(painter: _painter);
  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }
}

class _AlbumGroundLeaf extends LeafRenderObjectWidget {
  const _AlbumGroundLeaf({required this.painter});
  final BravaisAlbumGroundPainter painter;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderBravaisAlbumGround(painter);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderBravaisAlbumGround renderObject,
  ) => renderObject.painter = painter;
}

class RenderBravaisAlbumGround extends RenderBox {
  RenderBravaisAlbumGround(this._painter);
  BravaisAlbumGroundPainter _painter;
  set painter(BravaisAlbumGroundPainter value) {
    if (identical(value, _painter)) return;
    if (attached) _painter.removeListener(markNeedsPaint);
    _painter = value;
    if (attached) _painter.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;
  @override
  bool get isRepaintBoundary => true;
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;
  @override
  void performResize() => size = constraints.biggest;
  @override
  Rect get paintBounds => hasSize ? _painter.paintBounds(size) : Rect.zero;
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _painter.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _painter.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.setIsComplexHint();
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    try {
      _painter.paint(canvas, size);
    } finally {
      canvas.restore();
    }
  }

  @override
  bool hitTestSelf(Offset position) => false;
  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isHidden = true;
  }
}
