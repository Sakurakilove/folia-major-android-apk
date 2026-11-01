import 'dart:math' as math;

import 'wall_types.dart';

// Source wallView/pinch math: preserve seam-relative coordinates, device-pixel translation snapping and the two-finger world anchor.
WallPoint viewCenterFromCamera(WallCamera camera, WallView view) => WallPoint(
  (view.lineX - camera.x) / camera.scale,
  (view.height / 2 - camera.y) / camera.scale,
);
WallCamera cameraFromViewCenter(WallPoint center, WallView view) => WallCamera(
  view.lineX - center.x * view.scale,
  view.height / 2 - center.y * view.scale,
  view.scale,
);
WallBounds viewWorldBounds(
  WallPoint center,
  WallView view, {
  double seamWidth = 0,
  double overscan = 0,
}) => WallBounds(
  center.x - (view.lineX + seamWidth) / view.scale - overscan,
  center.x + (view.width - view.lineX + seamWidth) / view.scale + overscan,
  center.y - view.height / 2 / view.scale - overscan,
  center.y + view.height / 2 / view.scale + overscan,
);
WallCamera snapWallCamera(WallCamera camera, double dpr) => WallCamera(
  (camera.x * dpr + .5).floor() / dpr,
  (camera.y * dpr + .5).floor() / dpr,
  camera.scale,
);

class WallTouchPair {
  const WallTouchPair(this.x, this.y, this.distance);
  factory WallTouchPair.fromPoints(WallPoint a, WallPoint b) => WallTouchPair(
    (a.x + b.x) / 2,
    (a.y + b.y) / 2,
    math.max(
      1,
      math.sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)),
    ),
  );
  final double x, y, distance;
  Map<String, double> toJson() => {'x': x, 'y': y, 'distance': distance};
}

WallCamera pinchWallCamera(
  WallCamera camera,
  WallTouchPair start,
  WallTouchPair next,
) {
  final scale = (camera.scale * next.distance / start.distance).clamp(.32, 1.8),
      ratio = scale / camera.scale;
  return WallCamera(
    next.x - (start.x - camera.x) * ratio,
    next.y - (start.y - camera.y) * ratio,
    scale,
  );
}
