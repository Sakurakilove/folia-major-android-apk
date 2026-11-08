import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/poster/bravais_poster_paper.dart';

// A few strict source-paper observations in the existing shader case; no claim about complete posters, GPU profiles or full UI parity.
Future<void> checkWallPosterPaper() async {
  final program = await BravaisPosterPaperProgram.load(),
      reference = jsonDecode(
        File('test/fixtures/poster_paper_reference.json').readAsStringSync(),
      ),
      differences = <String>[];
  try {
    for (final row in reference['cases']) {
      final input = row['input'],
          paper = program.create(
            viewportHeight: 80,
            dpr: 1,
            album: input['album'],
            colors: input['custom'] == true
                ? const BravaisPosterPaperColors(
                    ground: ui.Color(0xff2762a4),
                    deep: ui.Color(0xff0a2142),
                    edge: ui.Color(0xff18243a),
                    paper: ui.Color(0xffe8f0f4),
                    block: ui.Color(0xff1b3d67),
                  )
                : const BravaisPosterPaperColors(),
          );
      final recorder = ui.PictureRecorder();
      paper.paint(ui.Canvas(recorder), const ui.Size(120, 144));
      final picture = recorder.endRecording(),
          image = await picture.toImage(120, 144);
      try {
        final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawStraightRgba,
            ))!,
            bytes = data.buffer.asUint8List(
              data.offsetInBytes,
              data.lengthInBytes,
            );
        for (final sample in row['samples']) {
          final offset =
                  (((sample['y'] as int) + 32) * 120 + (sample['x'] as int)) *
                  4,
              actual = bytes.sublist(offset, offset + 4);
          if (!listEquals(actual, sample['rgba'] as List)) {
            differences.add(
              '$input ${sample['x']},${sample['y']}: $actual / ${sample['rgba']}',
            );
          }
        }
      } finally {
        image.dispose();
        picture.dispose();
        paper.dispose();
      }
    }
    expect(differences, isEmpty);
  } finally {
    program.dispose();
  }
}
