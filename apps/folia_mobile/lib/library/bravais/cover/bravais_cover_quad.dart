import 'dart:math' as math;

import 'package:flutter/rendering.dart';

// Original three-corner measurement deliberately retains rotation/size rather than replacing the cover with an axis-aligned bounding box.
class BravaisCoverQuad {
  const BravaisCoverQuad(this.center, this.width, this.height, this.angle);
  final Offset center;
  final double width, height, angle;
  static BravaisCoverQuad? fromCorners(Offset a, Offset b, Offset c) {
    final width = (b - a).distance, height = (c - a).distance;
    if (width < 1 || height < 1) return null;
    return BravaisCoverQuad(
      (b + c) / 2,
      width,
      height,
      math.atan2(b.dy - a.dy, b.dx - a.dx),
    );
  }

  static BravaisCoverQuad lerp(
    BravaisCoverQuad from,
    BravaisCoverQuad to,
    double t,
  ) {
    var turn = to.angle - from.angle;
    while (turn > math.pi) {
      turn -= math.pi * 2;
    }
    while (turn < -math.pi) {
      turn += math.pi * 2;
    }
    double mix(double a, double b) => a + (b - a) * t;
    return BravaisCoverQuad(
      Offset(
        mix(from.center.dx, to.center.dx),
        mix(from.center.dy, to.center.dy),
      ),
      mix(from.width, to.width),
      mix(from.height, to.height),
      from.angle + turn * t,
    );
  }
}

BravaisCoverQuad? measureBravaisCover(
  RenderBox? box, {
  RenderObject? ancestor,
}) {
  if (box == null || !box.attached || !box.hasSize) return null;
  final transform = box.getTransformTo(ancestor), size = box.size;
  return BravaisCoverQuad.fromCorners(
    MatrixUtils.transformPoint(transform, Offset.zero),
    MatrixUtils.transformPoint(transform, Offset(size.width, 0)),
    MatrixUtils.transformPoint(transform, Offset(0, size.height)),
  );
}

// CSS's first background layer is square unless both explicit lengths exist.
Size bravaisDrawnCoverSize(String value, double width, double height) {
  final parts = value.split(',').first.trim().split(RegExp(r'\s+')),
      a = parts.firstOrNull ?? 'auto',
      b = parts.length > 1 ? parts[1] : 'auto';
  if (a == 'cover') return Size(width, height);
  if (a == 'contain') return Size.square(math.min(width, height));
  double? length(String token, double of) => token.endsWith('%')
      ? of * (_number(token) ?? double.nan) / 100
      : token.endsWith('px')
      ? _number(token)
      : null;
  final w = length(a, width), h = length(b, height);
  if (w != null && h != null) return Size(w, h);
  if (w != null) return Size.square(w);
  if (h != null) return Size.square(h);
  return Size(width, height);
}

double bravaisCoverOffset(String? token, double free) {
  if (token == null || token.isEmpty || token == 'center') return free / 2;
  if (token == 'left' || token == 'top') return 0;
  if (token == 'right' || token == 'bottom') return free;
  if (token.endsWith('%')) return free * (_number(token) ?? double.nan) / 100;
  final value = _number(token);
  return value == null || value.isNaN ? 0 : value;
}

final _floatPrefix = RegExp(r'^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?');
double? _number(String value) =>
    double.tryParse(_floatPrefix.firstMatch(value.trimLeft())?.group(0) ?? '');

// Cover position is measured in the tile's untransformed layout; focus pop scales the face about its own center, as in the original DOM probes.
BravaisCoverQuad bravaisTileCoverQuad({
  required BravaisCoverQuad tile,
  required Size tileSize,
  required Rect face,
  required bool hasBackgroundImage,
  String backgroundSize = 'cover',
  String backgroundPosition = '50% 50%',
  double popX = 1,
  double popY = 1,
}) {
  if (tileSize.isEmpty || face.isEmpty) {
    return BravaisCoverQuad(
      tile.center,
      tile.width * popX,
      tile.height * popY,
      tile.angle,
    );
  }
  final image = hasBackgroundImage
      ? bravaisDrawnCoverSize(backgroundSize, face.width, face.height)
      : face.size;
  final position = backgroundPosition
      .split(',')
      .first
      .trim()
      .split(RegExp(r'\s+'));
  final cx =
          face.center.dx +
          (bravaisCoverOffset(position.firstOrNull, face.width - image.width) +
                  image.width / 2 -
                  face.width / 2) *
              popX,
      cy =
          face.center.dy +
          (bravaisCoverOffset(
                    position.length > 1 ? position[1] : null,
                    face.height - image.height,
                  ) +
                  image.height / 2 -
                  face.height / 2) *
              popY,
      scale = tile.width / tileSize.width,
      dx = (cx - tileSize.width / 2) * scale,
      dy = (cy - tileSize.height / 2) * scale,
      cosine = math.cos(tile.angle),
      sine = math.sin(tile.angle);
  return BravaisCoverQuad(
    tile.center + Offset(dx * cosine - dy * sine, dx * sine + dy * cosine),
    image.width * popX * scale,
    image.height * popY * scale,
    tile.angle,
  );
}
