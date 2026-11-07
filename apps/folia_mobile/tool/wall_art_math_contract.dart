import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/bravais_album_art.dart';
import 'package:folia_mobile/library/bravais/tiles/artwork/bravais_artist_tone.dart';
import 'package:folia_mobile/library/bravais/tiles/artwork/bravais_art_style.dart';
import 'package:folia_mobile/library/wall/wall_types.dart';
import 'package:folia_mobile/library/wall/wall_css_paint.dart';
import 'package:folia_mobile/rendering/css_color.dart';
import 'package:folia_mobile/visualizer/motion/css_transition.dart';

import 'dart:ui' as ui;

// Original numeric contracts run inside the existing focused artwork check; they do not create another browser/UI suite.
Future<void> checkWallArtMath() async {
  final colorReference = jsonDecode(
    await File('test/fixtures/wall_color_reference.json').readAsString(),
  ) as Map;
  for (final c in colorReference['cases'] as List) {
    final daylight = c['daylight'] as bool;
    final base = daylight
            ? const ui.Color(0xff1c1917)
            : const ui.Color(0xff070707),
        accent = const ui.Color(0xfffd5c47),
        target = wallCssHsl(213, .62, .66),
        part = daylight ? .18 : .12;
    final light = CssValueTransition(
          CssColorValue.legacy(accent),
          CssColorValue.interpolate,
        ),
        dark = CssValueTransition(
          CssColorValue.modern(cssSrgbMix(base, accent, part)),
          CssColorValue.interpolate,
        );
    light.setTarget(
      CssColorValue.legacy(target),
      0,
      const CssTransitionSpec(400),
    );
    dark.setTarget(
      CssColorValue.modern(cssSrgbMix(base, target, part)),
      0,
      const CssTransitionSpec(400),
    );
    for (final sample in c['samples'] as List) {
      final time = (sample['time'] as num).toDouble();
      light.advance(time);
      dark.advance(time);
      final numbers = RegExp(r'-?\d*\.?\d+(?:e[-+]?\d+)?')
          .allMatches(sample['light'] as String)
          .map((m) => double.parse(m[0]!))
          .toList();
      for (final (actual, expected) in [
        (light.value.color.r * 255, numbers[0]),
        (light.value.color.g * 255, numbers[1]),
        (light.value.color.b * 255, numbers[2]),
      ]) {
        expect(actual.round(), closeTo(expected, 1));
      }
      if ((sample['dark'] as String).startsWith('oklab(')) {
        final numbers = RegExp(r'-?\d*\.?\d+(?:e[-+]?\d+)?')
                .allMatches(sample['dark'] as String)
                .map((m) => double.parse(m[0]!))
                .toList(),
            actual = CssOklab.fromColor(dark.value.color);
        expect(actual.l, closeTo(numbers[0], 2e-6));
        expect(actual.a, closeTo(numbers[1], 2e-6));
        expect(actual.b, closeTo(numbers[2], 2e-6));
      }
    }
  }
  final fixture = jsonDecode(
    await File('test/fixtures/wall_art_reference.json').readAsString(),
  ) as Map;
  for (final c in fixture['tones'] as List) {
    final tone = resolveBravaisArtistTone(
      Uint8List.fromList(List<int>.from(c['pixels'] as List)),
    );
    expect(tone.hue == null ? null : 'hsl(${tone.hue} 62% 66%)', c['result']);
  }
  for (final c in fixture['spots'] as List) {
    final side = c['side'] as int,
        pattern = c['pattern'],
        pixels = Uint8List(side * side * 4);
    for (var y = 0; y < side; y++) {
      for (var x = 0; x < side; x++) {
        final i = (y * side + x) * 4;
        pixels[i] = pattern == 'flat'
            ? 128
            : pattern == 'stripes'
            ? (x % 3 == 0 ? 255 : 0)
            : (x * 255 / side).floor();
        pixels[i + 1] = pattern == 'gradient' ? (y * 255 / side).floor() : 64;
        pixels[i + 2] = 128;
        pixels[i + 3] = 255;
      }
    }
    final result = findBravaisCoverSpots(pixels, side),
        expected = c['result'] as List;
    expect(result.length, expected.length);
    for (var i = 0; i < result.length; i++) {
      expect(result[i].x, closeTo((expected[i]['x'] as num).toDouble(), 1e-9));
      expect(result[i].y, closeTo((expected[i]['y'] as num).toDouble(), 1e-9));
    }
  }
  for (final c in fixture['placements'] as List) {
    final r = c['rect'] as Map,
        rect = WallRect(
          (r['x'] as num).toDouble(),
          (r['y'] as num).toDouble(),
          (r['width'] as num).toDouble(),
          (r['height'] as num).toDouble(),
        );
    final shard = bravaisShardPlacement(
          const [WallPoint(.35, .4), WallPoint(.65, .6)],
          c['seed'] as String,
          rect,
        ),
        mosaic = bravaisMosaicPlacement(
          rect,
          c['column'] as int,
          c['row'] as int,
        );
    for (final (actual, expected) in [
      (shard, c['shard']),
      (mosaic, c['mosaic']),
    ]) {
      expect(actual.size, closeTo((expected['size'] as num).toDouble(), 1e-8));
      expect(actual.x, closeTo((expected['x'] as num).toDouble(), 1e-8));
      expect(actual.y, closeTo((expected['y'] as num).toDouble(), 1e-8));
    }
    final css = BravaisArtStyle(
      mode: BravaisArtShaderMode.shard,
      placement: shard,
    ).backgroundRect!;
    expect(css.left, c['css']['x']);
    expect(css.top, c['css']['y']);
    expect(css.width, c['css']['size']);
  }
}
