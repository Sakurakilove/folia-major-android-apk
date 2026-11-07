import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:folia_mobile/library/bravais/seam/material/bravais_seam_material_look.dart';
import 'package:folia_mobile/library/bravais/seam/material/bravais_seam_material_painter.dart';
import 'package:folia_mobile/library/bravais/seam/material/bravais_seam_material_program.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_card_palette.dart';
import 'package:folia_mobile/rendering/gradients/css_gradient_program.dart';

// The existing native shader case samples only original static material surfaces. Full controls/fonts/animation/device equality remains a separate pending gate.
Future<void> checkWallSeamMaterials(CssGradientProgram gradients) async {
  final program = await BravaisSeamMaterialProgram.load(gradients: gradients),
      reference = jsonDecode(
        File('test/fixtures/seam_material_reference.json').readAsStringSync(),
      );
  const palette = BravaisCardPalette(
    background: ui.Color(0xff070707),
    ink: ui.Color(0xfff7f4ee),
    accent: ui.Color(0xfffd5c47),
    secondary: ui.Color(0xff6a48ff),
    daylight: false,
  );
  final differences = <String>[];
  try {
    for (final row in reference['cases']) {
      final input = row['input'],
          painter = BravaisSeamMaterialPainter(
            look: BravaisSeamMaterialLook(
              palette: palette,
              style: normalizeBravaisSeamStyle(input['style']),
              clear: input['clear'] ?? false,
              seeThrough: input['seeThrough'] ?? false,
              backdropBlur: input['backdropBlur'] ?? false,
            ),
            program: program,
            dpr: 1,
          );
      try {
        final grain = painter.grain;
        if (grain != null && grain.value == null) {
          final ready = Completer<void>();
          void imageReady() {
            if (ready.isCompleted) return;
            if (grain.error != null) {
              ready.completeError(grain.error!, grain.errorStack);
            } else if (grain.value != null) {
              ready.complete();
            }
          }

          grain.addListener(imageReady);
          try {
            imageReady();
            await ready.future;
          } finally {
            grain.removeListener(imageReady);
          }
        }
        final width = row['width'] as int,
            height = row['height'] as int,
            recorder = ui.PictureRecorder();
        painter.paint(
          ui.Canvas(recorder),
          ui.Size(width.toDouble(), height.toDouble()),
        );
        final picture = recorder.endRecording(),
            image = await picture.toImage(width, height);
        try {
          final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.rawStraightRgba,
              ))!,
              values = bytes.buffer.asUint8List(
                bytes.offsetInBytes,
                bytes.lengthInBytes,
              );
          for (final sample in row['samples']) {
            final offset =
                ((sample['y'] as int) * width + (sample['x'] as int)) * 4;
            final actual = values.sublist(offset, offset + 4);
            if (!listEquals(actual, sample['rgba'] as List)) {
              differences.add(
                '$input ${sample['x']},${sample['y']}: $actual / ${sample['rgba']}',
              );
            }
          }
        } finally {
          image.dispose();
          picture.dispose();
        }
      } finally {
        painter.dispose();
      }
    }
    expect(differences, isEmpty);
  } finally {
    program.dispose();
  }
}
