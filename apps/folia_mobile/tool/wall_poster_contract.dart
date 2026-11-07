import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/poster/bravais_album_composition.dart';
import 'package:folia_mobile/library/bravais/poster/bravais_poster_composition.dart';
import 'package:folia_mobile/library/bravais/poster/bravais_poster_palette.dart';
import 'package:folia_mobile/library/bravais/poster/bravais_poster_random.dart';
import 'package:folia_mobile/rendering/visualizer_color_mix.dart';
import 'package:folia_mobile/visualizer/motion/bezier.dart';
import 'package:folia_mobile/tempera/tempera_palette.dart';
import 'package:folia_mobile/theme/folia_theme.dart';

// Extend the existing wall case with original pure geometry/palette observations; this is not a visual or complete-mode acceptance gate.
void checkWallPosters() {
  final curves = jsonDecode(
    File('test/fixtures/chromium_bezier_reference.json').readAsStringSync(),
  );
  for (final row in curves['cases']) {
    final c = List<num>.from(row['curve']);
    for (final sample in row['samples']) {
      expect(
        cssBezier(
          c[0].toDouble(),
          c[1].toDouble(),
          c[2].toDouble(),
          c[3].toDouble(),
          (sample['at'] as num).toDouble(),
        ),
        closeTo(sample['value'], 1e-13),
        reason: 'Original Chromium C++ $c at ${sample['at']}',
      );
    }
  }

  final reference = jsonDecode(
    File('test/fixtures/poster_reference.json').readAsStringSync(),
  );
  void compare(dynamic actual, dynamic expected, String path) {
    if (actual is Map && expected is Map) {
      expect(actual.keys.toSet(), expected.keys.toSet(), reason: path);
      for (final key in expected.keys) {
        compare(actual[key], expected[key], '$path.$key');
      }
    } else if (actual is List && expected is List) {
      expect(actual.length, expected.length, reason: path);
      for (var i = 0; i < expected.length; i++) {
        compare(actual[i], expected[i], '$path[$i]');
      }
    } else if (actual is num && expected is num) {
      expect(actual, closeTo(expected, 1e-10), reason: path);
    } else {
      expect(actual, expected, reason: path);
    }
  }

  for (final row in reference['geometry']) {
    final seed = row['seed'] as String,
        artist = resolveBravaisPosterComposition(seed),
        random = createBravaisPosterRandom(hashBravaisPosterSeed(seed));
    expect(hashBravaisPosterSeed(seed), row['hash']);
    compare(List.generate(5, (_) => random()), row['random'], '$seed.random');
    compare(artist.toJson(), row['artist'], '$seed.artist');
    compare(
      resolveBravaisAlbumComposition(seed).toJson(),
      row['album'],
      '$seed.album',
    );
    expect(artist.shape.cssClipPath, row['clip'], reason: seed);
    if (artist.shape case final BravaisPosterPolygon shape) {
      compare(
        [
          for (final p in shape.risen()) [p.dx, p.dy],
        ],
        row['risen'],
        '$seed.risen',
      );
    }
  }
  for (final row in reference['palettes']) {
    final result = resolveTemperaPalette(
      FoliaTheme.fromJson(Map<String, dynamic>.from(row['theme'])),
      row['colorMode'],
      List<String>.from(row['coverColors']),
    );
    compare(
      result.toJson(),
      row['expected'],
      'tempera:${row['colorMode']}:${row['theme']['backgroundColor']}:${row['coverColors']}',
    );
  }
  for (final row in reference['posterPalettes']) {
    final colors = List<String>.from(row['colors']);
    compare(
      resolveBravaisPosterPalette(colors)?.toJson(),
      row['artist'],
      'artist:$colors',
    );
    compare(
      resolveBravaisAlbumPalette(colors)?.toJson(),
      row['album'],
      'album:$colors',
    );
  }
  for (final row in reference['colorCases']) {
    final input = row['input'] as String,
        channels = visualizerColorChannels(input);
    compare(
      channels == null
          ? null
          : {'r': channels.r, 'g': channels.g, 'b': channels.b},
      row['channels'],
      'channels:$input',
    );
    expect(visualizerColorWithAlpha(input, .35), row['alpha'], reason: input);
    for (final mix in row['mixes']) {
      expect(
        mixVisualizerColors(
          input,
          mix['to'],
          (mix['amount'] as num).toDouble(),
          .7,
        ),
        mix['expected'],
        reason: 'mix:$input',
      );
    }
  }
  expect(
    interleaveBravaisPosterColors([
      ['a', 'b'],
      [],
      ['c'],
      ['d', 'e', 'f'],
    ]),
    reference['interleaved'],
  );
}
