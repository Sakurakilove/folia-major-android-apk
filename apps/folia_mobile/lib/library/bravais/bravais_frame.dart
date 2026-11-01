import 'dart:math' as math;

import '../wall/seam_plan.dart';
import '../wall/wall_types.dart';
import '../wall/wall_view.dart';

// Original split-wall frame: two world layers and the paper opening tilt together about the seam's right edge.
const bravaisMetrics = WallMetrics(128, 8);
double bravaisScale(double viewportWidth) => viewportWidth < 640
    ? .52
    : viewportWidth < 1100
    ? .64
    : .76;

class BravaisTilt {
  const BravaisTilt(this.deg, this.pivotX, this.pivotY);
  final double deg, pivotX, pivotY;
  Map<String, double> toJson() => {
    'deg': deg,
    'pivotX': pivotX,
    'pivotY': pivotY,
  };
}

class BravaisFrame {
  const BravaisFrame({
    required this.left,
    required this.right,
    required this.scale,
    required this.seamX,
    required this.seamWidth,
    required this.seamVisible,
    required this.contentOpacity,
    required this.tabVisible,
    required this.tabSide,
    required this.tilt,
    required this.anchorX,
  });
  final WallPoint left, right;
  final double scale, seamX, seamWidth, contentOpacity;
  final bool seamVisible, tabVisible;
  final WallSeamSide tabSide;
  final BravaisTilt tilt;
  final double? anchorX;
  Map<String, Object> toJson() => {
    'left': left.toJson(),
    'right': right.toJson(),
    'scale': scale,
    'seam': {'x': seamX, 'width': seamWidth, 'visible': seamVisible},
    'contentOpacity': contentOpacity,
    'tab': {'visible': tabVisible, 'side': tabSide.name},
    'tilt': tilt.toJson(),
  };
}

BravaisFrame computeBravaisFrame({
  required WallPoint center,
  required WallView view,
  required double? anchorX,
  required double openWidth,
  required double contentWidth,
  required bool hidden,
  bool poster = false,
  double tiltDeg = 0,
}) {
  final camera = cameraFromViewCenter(center, view);
  if (anchorX == null) {
    return BravaisFrame(
      left: WallPoint(camera.x, camera.y),
      right: WallPoint(camera.x, camera.y),
      scale: view.scale,
      seamX: view.width / 2,
      seamWidth: 0,
      seamVisible: false,
      contentOpacity: 0,
      tabVisible: false,
      tabSide: WallSeamSide.left,
      tilt: const BravaisTilt(0, 0, 0),
      anchorX: null,
    );
  }
  final geo = seamGeometry(
        anchorX: anchorX,
        cameraX: center.x,
        openWidth: openWidth,
        view: view,
        edge: poster ? 0 : wallSeamEdge,
      ),
      offsets = seamSplitOffsets(geo.width, view.scale, bravaisMetrics),
      opacity = ((geo.width / math.max(contentWidth, 1) - .35) / .65).clamp(
        0.0,
        1.0,
      );
  return BravaisFrame(
    left: WallPoint(camera.x + offsets.left, camera.y),
    right: WallPoint(camera.x + offsets.right, camera.y),
    scale: view.scale,
    seamX: geo.screenX,
    seamWidth: geo.width,
    seamVisible: geo.width >= 1,
    contentOpacity: opacity,
    tabVisible: hidden || geo.collapsed,
    tabSide: geo.side,
    tilt: BravaisTilt(tiltDeg, geo.screenX + geo.width / 2, view.height / 2),
    anchorX: anchorX,
  );
}

({double anchorX, WallPoint center}) planPosterOpening({
  required WallPoint center,
  required WallView view,
  required double width,
  double? preferX,
}) {
  final offset = (width / 2 - view.lineX) / view.scale,
      anchor =
          preferX ?? nearestSeamBoundaryX(center.x + offset, bravaisMetrics);
  return (anchorX: anchor, center: WallPoint(anchor - offset, center.y));
}

WallBounds tiltReach(WallView view, BravaisTilt tilt) {
  if (tilt.deg.abs() < .001) return const WallBounds(0, 0, 0, 0);
  final radians = -tilt.deg * math.pi / 180,
      cos = math.cos(radians),
      sin = math.sin(radians);
  var minX = double.infinity,
      maxX = double.negativeInfinity,
      minY = double.infinity,
      maxY = double.negativeInfinity;
  for (final x in [0.0, view.width]) {
    for (final y in [0.0, view.height]) {
      final dx = x - tilt.pivotX,
          dy = y - tilt.pivotY,
          px = tilt.pivotX + dx * cos - dy * sin,
          py = tilt.pivotY + dx * sin + dy * cos;
      minX = math.min(minX, px);
      maxX = math.max(maxX, px);
      minY = math.min(minY, py);
      maxY = math.max(maxY, py);
    }
  }
  return WallBounds(-minX, maxX - view.width, -minY, maxY - view.height);
}

WallBounds bravaisVisibleWorldBounds({
  required WallPoint center,
  required WallView view,
  required double? anchorX,
  required double openWidth,
  required double contentWidth,
  required bool hidden,
  bool poster = false,
  double tiltDeg = 0,
}) {
  final bounds = viewWorldBounds(center, view, seamWidth: openWidth);
  if (tiltDeg.abs() < .001 || anchorX == null) return bounds;
  final frame = computeBravaisFrame(
        center: center,
        view: view,
        anchorX: anchorX,
        openWidth: openWidth,
        contentWidth: contentWidth,
        hidden: hidden,
        poster: poster,
        tiltDeg: tiltDeg,
      ),
      reach = tiltReach(view, frame.tilt);
  return WallBounds(
    bounds.left - reach.left / view.scale,
    bounds.right + reach.right / view.scale,
    bounds.top - reach.top / view.scale,
    bounds.bottom + reach.bottom / view.scale,
  );
}

bool bravaisNeedsRecull(
  WallBounds visible,
  WallBounds? culled, {
  bool prepare = false,
  double overscan = 300,
}) {
  if (culled == null) return true;
  final pad = (overscan - 160) * (prepare ? .5 : 1);
  return visible.left < culled.left - pad ||
      visible.right > culled.right + pad ||
      visible.top < culled.top - pad ||
      visible.bottom > culled.bottom + pad;
}

double bravaisRubberBand(
  double value,
  double min,
  double max, {
  double resistance = .35,
}) => value < min
    ? min - (min - value) * resistance
    : value > max
    ? max + (value - max) * resistance
    : value;
