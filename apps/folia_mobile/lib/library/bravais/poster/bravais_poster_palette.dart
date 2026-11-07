import 'dart:math' as math;

import '../../../rendering/visualizer_color_mix.dart';
import '../../../tempera/tempera_palette.dart';
import '../../../theme/folia_theme.dart';
import '../tiles/bravais_item.dart';

part 'bravais_album_palette.dart';

// Palette inputs retain raw URL equality and the source track-before-album order. Extraction/permissions stay with the shared native artwork pipeline.
List<String> bravaisPosterPaletteSources(List<BravaisItem> items) {
  final urls = <String>[];
  for (final kind in [BravaisItemKind.track, BravaisItemKind.album]) {
    for (final item in items) {
      final url = item.coverUrl;
      if (item.kind == kind &&
          url != null &&
          url.isNotEmpty &&
          !urls.contains(url) &&
          urls.length < 3) {
        urls.add(url);
      }
    }
  }
  return List.unmodifiable(urls);
}

List<String> interleaveBravaisPosterColors(List<List<String>> perCover) =>
    List.unmodifiable([
      for (var rank = 0; rank < 2; rank++)
        for (final colors in perCover)
          if (rank < colors.length && colors[rank].isNotEmpty) colors[rank],
    ]);

FoliaTheme _posterTheme(List<String> colors, {bool album = false}) =>
    FoliaTheme.fromJson({
      'name': 'bravais-poster',
      'backgroundColor': album ? _albumPaper : '#2b2b2e',
      'primaryColor': album ? _albumInk : '#f4f4f4',
      'accentColor': colors[0],
      'secondaryColor': colors.length > 1 ? colors[1] : colors[0],
      'fontStyle': 'sans',
      'animationIntensity': 'normal',
    });

class BravaisPosterPalette {
  const BravaisPosterPalette({
    required this.ground,
    required this.groundDeep,
    required this.edge,
    required this.shape,
    required this.ghost,
    required this.extrude,
    required this.scrap,
    required this.wallTint,
  });
  final String ground, groundDeep, edge, shape, ghost, scrap, wallTint;
  final List<String> extrude;
  Map<String, dynamic> toJson() => {
    'ground': ground,
    'groundDeep': groundDeep,
    'edge': edge,
    'shape': shape,
    'ghost': ghost,
    'extrude': extrude,
    'scrap': scrap,
    'wallTint': wallTint,
  };
}

BravaisPosterPalette? resolveBravaisPosterPalette(List<String> colors) {
  if (colors.length < 2) return null;
  final p = resolveTemperaPalette(_posterTheme(colors), 'gradient', colors),
      paper = p.paper,
      a = p.tone1,
      b = p.tone2,
      c = p.tone3;
  return BravaisPosterPalette(
    ground: b,
    groundDeep: mixVisualizerColors(a, b, .4),
    edge: mixVisualizerColors(paper, a, .5),
    shape: mixVisualizerColors(paper, a, .3),
    ghost: a,
    extrude: List.unmodifiable([c, mixVisualizerColors(b, c, .5), b, a]),
    scrap: c,
    wallTint: c,
  );
}
