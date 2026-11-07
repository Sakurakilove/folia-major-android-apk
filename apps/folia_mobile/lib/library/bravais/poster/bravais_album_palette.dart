part of 'bravais_poster_palette.dart';

// Album paper/ink and stable accent ranking are the original rules; a vivid color too close to the darkest block must not win merely on saturation.
const _albumPaper = '#efe9dc', _albumInk = '#141210';

class BravaisAlbumPalette {
  const BravaisAlbumPalette({
    required this.paper,
    required this.ink,
    required this.block,
    required this.blockDeep,
    required this.title,
    required this.extrude,
    required this.accent,
  });
  final String paper, ink, block, blockDeep, title, accent;
  final List<String> extrude;
  Map<String, dynamic> toJson() => {
    'paper': paper,
    'ink': ink,
    'block': block,
    'blockDeep': blockDeep,
    'title': title,
    'extrude': extrude,
    'accent': accent,
  };
}

VisualizerColorChannels _channels(String color) =>
    visualizerColorChannels(color) ?? (r: 128.0, g: 128.0, b: 128.0);
double _luminance(String color) {
  final c = _channels(color);
  return .2126 * c.r + .7152 * c.g + .0722 * c.b;
}

double _saturation(String color) {
  final c = _channels(color),
      max = math.max(c.r, math.max(c.g, c.b)),
      min = math.min(c.r, math.min(c.g, c.b));
  return max == 0 ? 0 : (max - min) / max;
}

BravaisAlbumPalette? resolveBravaisAlbumPalette(List<String> colors) {
  if (colors.length < 2) return null;
  final p = resolveTemperaPalette(
        _posterTheme(colors, album: true),
        'gradient',
        colors,
      ),
      tones = p.tones,
      ranked = tones.indexed.toList();
  ranked.sort((a, b) {
    final difference = _luminance(a.$2).compareTo(_luminance(b.$2));
    return difference != 0 ? difference : a.$1.compareTo(b.$1);
  });
  final darkest = ranked.first.$2,
      block = mixVisualizerColors(darkest, _albumInk, .25),
      blockChannels = _channels(block),
      candidates = [...tones.where((t) => t != darkest), ...colors];
  double score(String color) {
    final a = _channels(color),
        r = a.r - blockChannels.r,
        g = a.g - blockChannels.g,
        b = a.b - blockChannels.b;
    // Scale first, as Math.hypot does, instead of overflowing squared channels.
    final magnitude = math.max(r.abs(), math.max(g.abs(), b.abs()));
    final distance = magnitude == 0
        ? 0.0
        : magnitude *
              math.sqrt(
                (r / magnitude) * (r / magnitude) +
                    (g / magnitude) * (g / magnitude) +
                    (b / magnitude) * (b / magnitude),
              );
    return _saturation(color) * (distance / 441);
  }

  final scored = candidates.indexed
      .map((p) => (index: p.$1, color: p.$2, score: score(p.$2)))
      .toList();
  scored.sort((a, b) {
    final difference = b.score.compareTo(a.score);
    return difference != 0 ? difference : a.index.compareTo(b.index);
  });
  final accent = scored.firstOrNull?.color ?? p.accent,
      title = mixVisualizerColors(_albumPaper, accent, .12);
  return BravaisAlbumPalette(
    paper: mixVisualizerColors(_albumPaper, tones[0], .06),
    ink: _albumInk,
    block: block,
    blockDeep: mixVisualizerColors(block, _albumInk, .45),
    title: title,
    extrude: List.unmodifiable([
      mixVisualizerColors(title, block, .25),
      mixVisualizerColors(title, block, .45),
      mixVisualizerColors(title, block, .65),
      mixVisualizerColors(block, _albumInk, .3),
    ]),
    accent: accent,
  );
}
