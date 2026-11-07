import 'dart:math' as math;
import 'dart:ui';

import '../../../rendering/js_number.dart';
import 'bravais_poster_random.dart';

// Original seed-fixed poster geometry. Shape paths preserve the CSS toFixed(3) boundaries and the full upper bleed, rather than cropping to the visible viewport.
sealed class BravaisPosterShape {
  const BravaisPosterShape();
  Map<String, dynamic> toJson();
  String get cssClipPath;
  Path path(Size viewport);
}

class BravaisPosterPolygon extends BravaisPosterShape {
  BravaisPosterPolygon(Iterable<Offset> points)
    : points = List.unmodifiable(points);
  final List<Offset> points;
  List<Offset> risen([double rise = 100]) => List.generate(points.length, (i) {
    final point = points[i];
    if (point.dy != 0) return point;
    final previous = points[(i - 1 + points.length) % points.length],
        next = points[(i + 1) % points.length],
        side = previous.dy != 0
            ? previous
            : next.dy != 0
            ? next
            : null;
    return Offset(
      side == null
          ? point.dx
          : point.dx + ((point.dx - side.dx) / side.dy) * rise,
      -rise,
    );
  }, growable: false);
  @override
  Map<String, dynamic> toJson() => {
    'kind': 'polygon',
    'points': [
      for (final p in points) [p.dx, p.dy],
    ],
  };
  @override
  String get cssClipPath =>
      'polygon(${risen().map((p) => '${_fixed(p.dx)}% ${_fixed(p.dy + 100)}cqh').join(', ')})';
  @override
  Path path(Size viewport) {
    final points = risen()
        .map(
          (p) => Offset(
            double.parse(_fixed(p.dx)) * viewport.width / 100,
            (double.parse(_fixed(p.dy + 100)) - 100) * viewport.height / 100,
          ),
        )
        .toList(growable: false);
    return Path()..addPolygon(points, true);
  }
}

class BravaisPosterCircle extends BravaisPosterShape {
  const BravaisPosterCircle(this.cx, this.cy);
  final double cx, cy;
  @override
  Map<String, dynamic> toJson() => {'kind': 'circle', 'cx': cx, 'cy': cy};
  @override
  String get cssClipPath =>
      'circle(min(34cqw, 27cqh) at ${jsNumberString(cx)}% ${_fixed(cy + 100)}cqh)';
  @override
  Path path(Size viewport) => Path()
    ..addOval(
      Rect.fromCircle(
        center: Offset(
          viewport.width * cx / 100,
          (double.parse(_fixed(cy + 100)) - 100) * viewport.height / 100,
        ),
        radius: math.min(viewport.width * .34, viewport.height * .27),
      ),
    );
}

String _fixed(double value) => (value == 0 ? 0.0 : value).toStringAsFixed(3);
typedef BravaisPosterScrap = ({
  double x,
  double y,
  double size,
  double deg,
  double opacity,
});
typedef BravaisPosterThrough = ({double y, double deg});

class BravaisPosterComposition {
  const BravaisPosterComposition({
    required this.shape,
    required this.ghost,
    required this.through,
    required this.scraps,
    required this.hatch,
    required this.dots,
  });
  final BravaisPosterShape shape;
  final Offset ghost, dots;
  final List<BravaisPosterThrough> through;
  final List<BravaisPosterScrap> scraps;
  final ({String side, double y}) hatch;
  Map<String, dynamic> toJson() => {
    'shape': shape.toJson(),
    'ghost': {'x': ghost.dx, 'y': ghost.dy},
    'through': [
      for (final p in through) {'y': p.y, 'deg': p.deg},
    ],
    'scraps': [
      for (final p in scraps)
        {
          'x': p.x,
          'y': p.y,
          'size': p.size,
          'deg': p.deg,
          'opacity': p.opacity,
        },
    ],
    'hatch': {'side': hatch.side, 'y': hatch.y},
    'dots': {'x': dots.dx, 'y': dots.dy},
  };
}

BravaisPosterComposition resolveBravaisPosterComposition(String seed) {
  final random = createBravaisPosterRandom(hashBravaisPosterSeed(seed));
  double between(double min, double max) => min + (max - min) * random();
  final which = (random() * 4).floor(), mirror = random() < .4;
  double flip(double x) => mirror ? 100 - x : x;
  const polygons = [
    [Offset(18, 0), Offset(100, 0), Offset(100, 58), Offset(46, 74)],
    [Offset(0, 0), Offset(100, 0), Offset(100, 50), Offset(0, 66)],
    [Offset(44, 0), Offset(100, 0), Offset(100, 66), Offset(58, 76)],
  ];
  final shape = which == 3
      ? BravaisPosterCircle(flip(64), 30)
      : BravaisPosterPolygon(
          polygons[which].map((p) => Offset(flip(p.dx), p.dy)),
        );
  final ghostSign = random() < .5 ? -1 : 1,
      spots = [
        const Offset(-2, 30),
        const Offset(4, 20),
        const Offset(30, 24),
        const Offset(16, 40),
      ],
      scraps = <BravaisPosterScrap>[];
  for (var rank = 0; rank < 2; rank++) {
    final candidates = spots
            .where((s) => scraps.every((p) => (p.y - s.dy).abs() >= 10))
            .toList(),
        spot = candidates[(random() * candidates.length).floor()];
    spots.remove(spot);
    scraps.add((
      x: spot.dx,
      y: spot.dy,
      size: [8, 5][rank] * between(.85, 1.15),
      deg: between(-9, 9),
      opacity: [.8, .55][rank],
    ));
  }
  return BravaisPosterComposition(
    shape: shape,
    ghost: Offset(16.0 * ghostSign * (mirror ? -1 : 1), 16),
    through: List.unmodifiable([
      (y: between(8, 18), deg: between(2, 7) * (random() < .5 ? -1 : 1)),
      (y: between(78, 88), deg: between(3, 8) * (random() < .5 ? -1 : 1)),
    ]),
    scraps: List.unmodifiable(scraps),
    hatch: (side: mirror ? 'right' : 'left', y: between(11, 16)),
    dots: Offset(between(30, 56), between(7, 11)),
  );
}
