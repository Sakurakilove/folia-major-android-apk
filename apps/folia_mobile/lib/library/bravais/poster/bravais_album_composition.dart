import 'bravais_poster_random.dart';

// Album composition uses its own prefixed seed and original PRNG call order. These values never resample during animation or camera movement.
class BravaisAlbumComposition {
  const BravaisAlbumComposition({
    required this.coverDeg,
    required this.tape,
    required this.divider,
    required this.underline,
    required this.hero,
    required this.ghostSide,
  });
  final double coverDeg, underline;
  final ({double x, double deg}) tape;
  final ({double left, double right}) divider;
  final ({double x, double y, double deg}) hero;
  final String ghostSide;
  Map<String, dynamic> toJson() => {
    'coverDeg': coverDeg,
    'tape': {'x': tape.x, 'deg': tape.deg},
    'divider': {'left': divider.left, 'right': divider.right},
    'underline': underline,
    'hero': {'x': hero.x, 'y': hero.y, 'deg': hero.deg},
    'ghostSide': ghostSide,
  };
}

BravaisAlbumComposition resolveBravaisAlbumComposition(String seed) {
  final random = createBravaisPosterRandom(
    hashBravaisPosterSeed('album:$seed'),
  );
  double between(double min, double max) => min + (max - min) * random();
  int sign() => random() < .5 ? -1 : 1;
  final high = between(44, 50), low = between(56, 62), leftHigh = random() < .5;
  return BravaisAlbumComposition(
    coverDeg: between(2.5, 6) * sign(),
    tape: (x: between(28, 58), deg: between(-5, 5)),
    divider: (left: leftHigh ? high : low, right: leftHigh ? low : high),
    underline: between(38, 62),
    hero: (
      x: between(.04, .12),
      y: between(.12, .22),
      deg: between(2, 7) * sign(),
    ),
    ghostSide: random() < .5 ? 'left' : 'right',
  );
}
