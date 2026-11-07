import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/rendering/noise/native_svg_noise.dart';
import 'package:folia_mobile/rendering/noise/svg_noise_texture.dart';

// Extend the existing native artwork case with full-DPR ownership and forty exact source-SVG pixel observations. This is not all material/CSS/device pixel acceptance.
Future<void> checkWallNoise() async {
  final native = NativeSvgNoise(),
      reference = jsonDecode(
        File('test/fixtures/wall_noise_reference.json').readAsStringSync(),
      );
  for (final row in reference['cases']) {
    final extent = (row['logical'] as num).toDouble(),
        dpr = (row['dpr'] as num).toDouble(),
        image = await prepareSvgNoiseTexture(
          native: native,
          recipe: SvgNoiseRecipe.values.byName(row['recipe']),
          cssExtent: extent,
          dpr: dpr,
          whiteInk: row['whiteInk'] ?? false,
        );
    try {
      expect(image.width, (extent * dpr).ceil());
      expect(image.height, image.width);
      final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!,
          pixels = bytes.buffer.asUint8List(
            bytes.offsetInBytes,
            bytes.lengthInBytes,
          );
      for (final sample in row['samples']) {
        final offset =
            ((sample['y'] as int) * image.width + (sample['x'] as int)) * 4;
        expect(
          pixels.sublist(offset, offset + 4),
          sample['rgba'],
          reason: '${row['name']} DPR$dpr ${sample['x']},${sample['y']}',
        );
      }
    } finally {
      image.dispose();
    }
  }
  final pixels = await native.create(
    SvgNoiseRecipe.paper,
    cssExtent: 180,
    dpr: 1,
  );
  expect(pixels.length, 180 * 180 * 4);
  pixels.dispose();
  pixels.dispose();
  expect(() => pixels.bytes, throwsStateError);
  await expectLater(
    native.create(SvgNoiseRecipe.paper, cssExtent: 180, dpr: 0),
    throwsStateError,
  );
}
