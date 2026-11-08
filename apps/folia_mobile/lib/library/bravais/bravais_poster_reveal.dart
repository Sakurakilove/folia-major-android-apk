import 'dart:math' as math;

import '../wall/wall_types.dart';
import 'bravais_frame.dart';

// Snapshot the same frame input used to draw both halves. Reveal work runs on a discrete focus/locate action, not on display frames or through a platform bridge.
class BravaisRevealFrame {
  const BravaisRevealFrame({
    required this.center,
    required this.view,
    required this.anchorX,
    required this.openWidth,
    required this.contentWidth,
    required this.hidden,
    this.poster = false,
    this.tiltDeg = 0,
  });
  final WallPoint center;
  final WallView view;
  final double? anchorX;
  final double openWidth, contentWidth, tiltDeg;
  final bool hidden, poster;
  BravaisFrame draw([WallPoint? next]) => computeBravaisFrame(
    center: next ?? center,
    view: view,
    anchorX: anchorX,
    openWidth: openWidth,
    contentWidth: contentWidth,
    hidden: hidden,
    poster: poster,
    tiltDeg: tiltDeg,
  );
}

WallBounds bravaisPosterScreenBox(
  WallGeometry rect,
  BravaisRevealFrame frame, {
  WallPoint? center,
}) {
  final drawn = frame.draw(center),
      half = frame.anchorX != null && rect.x + rect.width / 2 < frame.anchorX!
          ? drawn.left
          : drawn.right,
      radians = drawn.tilt.deg * math.pi / 180,
      cos = math.cos(radians),
      sin = math.sin(radians);
  var left = double.infinity,
      right = double.negativeInfinity,
      top = double.infinity,
      bottom = double.negativeInfinity;
  for (final corner in [
    (rect.x, rect.y),
    (rect.x + rect.width, rect.y),
    (rect.x, rect.y + rect.height),
    (rect.x + rect.width, rect.y + rect.height),
  ]) {
    final dx = corner.$1 * drawn.scale + half.x - drawn.tilt.pivotX,
        dy = corner.$2 * drawn.scale + half.y - drawn.tilt.pivotY,
        x = drawn.tilt.pivotX + dx * cos - dy * sin,
        y = drawn.tilt.pivotY + dx * sin + dy * cos;
    left = math.min(left, x);
    right = math.max(right, x);
    top = math.min(top, y);
    bottom = math.max(bottom, y);
  }
  return WallBounds(left, right, top, bottom);
}

double _shiftInto(double start, double end, double low, double high) {
  if (end - start > high - low) return (low + high) / 2 - (start + end) / 2;
  if (start < low) return low - start;
  if (end > high) return high - end;
  return 0;
}

({WallPoint center, bool fits}) _solve(
  WallGeometry rect,
  BravaisRevealFrame frame,
  double pad,
  double bottomInset,
  WallPoint center,
  bool lockX,
) {
  final cos = math.cos(frame.tiltDeg * math.pi / 180), view = frame.view;
  var current = center, fits = false;
  for (var step = 0; step < 8; step++) {
    final box = bravaisPosterScreenBox(rect, frame, center: current),
        neededX = _shiftInto(box.left, box.right, pad, view.width - pad),
        shiftX = lockX ? 0.0 : neededX,
        shiftY = _shiftInto(
          box.top,
          box.bottom,
          pad,
          view.height - bottomInset,
        );
    fits = neededX.abs() < .5 && shiftY.abs() < .5;
    if (shiftX.abs() < .5 && shiftY.abs() < .5) break;
    current = WallPoint(
      current.x - shiftX / view.scale,
      current.y - shiftY / (view.scale * math.max(cos, .1)),
    );
  }
  return (center: current, fits: fits);
}

WallPoint resolveBravaisPosterRevealCenter({
  required WallGeometry rect,
  required BravaisRevealFrame frame,
  required double posterWidth,
  required double pad,
  required double bottomInset,
}) {
  final free = _solve(
        rect,
        frame,
        pad,
        bottomInset,
        frame.center,
        false,
      ).center,
      anchor = frame.anchorX;
  if (anchor == null) return free;
  final view = frame.view,
      need = posterWidth / 2,
      openLow = anchor - (view.width - need - view.lineX) / view.scale,
      openHigh = anchor + (view.lineX - need) / view.scale,
      openX = math.min(openHigh, math.max(openLow, free.x));
  if ((openX - free.x).abs() < .5 / view.scale) return free;
  final open = _solve(
    rect,
    frame,
    pad,
    bottomInset,
    WallPoint(openX, free.y),
    true,
  );
  return open.fits ? open.center : free;
}
