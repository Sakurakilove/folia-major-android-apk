part of 'bravais_seam_viewport.dart';

// Paper and the retained content share one screen-space tilt. Poster paper bleeds 40vh beyond each edge; its content remains one viewport high.
extension _BravaisSeamViewportPaint on RenderBravaisSeamViewport {
  void _paintContent(PaintingContext context, Offset offset) {
    if (child == null) return;
    final alpha = _frame.value.contentOpacity;
    if (alpha <= 0) {
      _opacity.layer = null;
      return;
    }
    void content(PaintingContext context, Offset offset) =>
        context.paintChild(child!, offset + contentOffset);
    if (alpha >= 1) {
      _opacity.layer = null;
      content(context, offset);
    } else {
      _opacity.layer = context.pushColorFilter(
        offset,
        ColorFilter.matrix([
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          alpha,
          0,
        ]),
        content,
        oldLayer: _opacity.layer,
      );
    }
  }

  void paintSeam(PaintingContext context, Offset offset) {
    if (!_frame.value.seamVisible) {
      _outerClip.layer = null;
      _paperClip.layer = null;
      _transform.layer = null;
      _opacity.layer = null;
      return;
    }
    _outerClip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (context, offset) {
        _transform.layer = context.pushTransform(
          needsCompositing,
          offset,
          tiltTransform,
          (context, offset) {
            final paper = paperBounds;
            _surfaceCache.paint(
              context,
              offset + paper.topLeft,
              _surface,
              paper.size,
            );
            _paperClip.layer = context.pushClipRect(
              needsCompositing,
              offset,
              paper,
              (context, offset) {
                void overlay(CustomPainter? painter) {
                  if (painter == null) return;
                  final canvas = context.canvas;
                  canvas.save();
                  canvas.translate(
                    offset.dx + paper.left,
                    offset.dy + paper.top,
                  );
                  painter.paint(canvas, paper.size);
                  canvas.restore();
                }

                overlay(_underlay);
                _paintContent(context, offset);
                overlay(_overlay);
              },
              clipBehavior: Clip.hardEdge,
              oldLayer: _paperClip.layer,
            );
          },
          oldLayer: _transform.layer,
        );
      },
      clipBehavior: Clip.hardEdge,
      oldLayer: _outerClip.layer,
    );
  }
}
