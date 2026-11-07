part of 'bravais_seam_opening.dart';

// Reopening selects a boundary in the current viewport instead of dragging the user back to an old off-screen seam.
extension BravaisSeamOpeningPlan on BravaisSeamOpening {
  void setAnchor(double? x) {
    camera.anchorX = x;
    camera.renderFrame();
  }

  bool isAnchorOnScreen() {
    final x = camera.anchorX;
    if (x == null) return false;
    final geometry = seamGeometry(
      anchorX: x,
      cameraX: camera.center.x,
      openWidth: 1,
      view: camera.view,
    );
    return geometry.screenX > 0 && geometry.screenX < camera.view.width;
  }

  ({double anchorX, WallPoint center}) planOpening(
    WallPoint center,
    double width,
    bool preferAnchor, {
    bool poster = false,
    BravaisWallShape? shape,
  }) {
    final prefer = preferAnchor ? camera.anchorX : null;
    if (poster) {
      return planPosterOpening(
        center: center,
        view: camera.view,
        width: width,
        preferX: prefer,
      );
    }
    final plan = blockSeamPlan(
      cameraX: center.x,
      openWidth: width,
      view: camera.view,
      metrics: bravaisMetrics,
      blockWidth: (shape ?? getShape()).blockSize.width,
      preferX: prefer,
    );
    return (anchorX: plan.x, center: WallPoint(plan.cameraX, center.y));
  }

  void reopenHere() {
    if (_closed || _layerKey == null || targetWidth <= 0) return;
    final plan = planOpening(
      camera.center,
      targetWidth,
      false,
      poster: camera.poster,
    );
    setAnchor(plan.anchorX);
    _animateWidth(targetWidth, from: 0);
    camera.tweenTo(plan.center);
  }

  bool isCollapsed() {
    final x = camera.anchorX;
    if (x == null || targetWidth <= 0) return false;
    final width = camera.openWidth > targetWidth
        ? camera.openWidth
        : targetWidth;
    return seamGeometry(
      anchorX: x,
      cameraX: camera.center.x,
      openWidth: width,
      view: camera.view,
      edge: camera.poster ? 0 : wallSeamEdge,
    ).collapsed;
  }
}
