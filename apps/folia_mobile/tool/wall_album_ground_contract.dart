import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/poster/bravais_album_composition.dart';
import 'package:folia_mobile/library/bravais/poster/bravais_poster_paper.dart';
import 'package:folia_mobile/library/bravais/poster/album/bravais_album_entrance.dart';
import 'package:folia_mobile/library/bravais/poster/album/bravais_album_ground_program.dart';
import 'package:folia_mobile/library/wall/wall_typography.dart';
import 'package:folia_mobile/rendering/css_opacity.dart';

// Small controlled source-ground observations share the existing shader case. Empty ghost excludes typography; this does not accept complete posters or device rendering.
Future<void> checkWallAlbumGround() async {
  final program = await BravaisAlbumGroundProgram.load(),
      paperProgram = await BravaisPosterPaperProgram.load(),
      reference = jsonDecode(
        File('test/fixtures/album_ground_reference.json').readAsStringSync(),
      ),
      differences = <String>[];
  try {
    for (final row in reference['cases']) {
      var now = 0.0;
      final frames = _GroundFrames(),
          entrance = BravaisAlbumEntrance(
            frames: frames,
            nowMs: () => now,
            words: const [],
          ),
          custom = row['custom'] == true,
          ground = program.create(
            composition: resolveBravaisAlbumComposition(reference['seed']),
            entrance: entrance,
            typography: const WallTypography(),
            ghost: '',
            dpr: 1,
            colors: custom
                ? const BravaisAlbumGroundColors(
                    paper: ui.Color(0xffe8f0f4),
                    ink: ui.Color(0xff192431),
                    block: ui.Color(0xff1b3d67),
                  )
                : const BravaisAlbumGroundColors(),
          ),
          paper = paperProgram.create(
            viewportHeight: 120,
            dpr: 1,
            album: true,
            colors: custom
                ? const BravaisPosterPaperColors(
                    paper: ui.Color(0xffe8f0f4),
                    block: ui.Color(0xff1b3d67),
                  )
                : const BravaisPosterPaperColors(),
          );
      void changed() {}
      ground.addListener(changed);
      try {
        final warm = ui.PictureRecorder();
        ground.paint(ui.Canvas(warm), const ui.Size(120, 80));
        warm.endRecording().dispose();
        final grain = ground.grain!, ready = Completer<void>();
        void loaded() {
          if (ready.isCompleted) return;
          if (grain.error != null) {
            ready.completeError(grain.error!, grain.errorStack);
          } else if (grain.value != null) {
            ready.complete();
          }
        }

        grain.addListener(loaded);
        loaded();
        try {
          await ready.future;
        } finally {
          grain.removeListener(loaded);
        }
        if (!custom && row['at'] == 0) {
          for (final diagnostic in reference['diagnostics']) {
            final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
            canvas.drawImage(
              grain.value!,
              const ui.Offset(0, -80),
              ui.Paint()
                ..colorFilter = cssOpacityFilter(
                  (diagnostic['opacity'] as num).toDouble(),
                ),
            );
            final picture = recorder.endRecording(),
                image = await picture.toImage(120, 120);
            try {
              final data = (await image.toByteData(
                    format: ui.ImageByteFormat.rawStraightRgba,
                  ))!,
                  bytes = data.buffer.asUint8List(
                    data.offsetInBytes,
                    data.lengthInBytes,
                  );
              for (final sample in diagnostic['samples']) {
                if ((sample['y'] as int) >= 80) continue;
                final offset =
                        ((sample['y'] as int) * 120 + (sample['x'] as int)) * 4,
                    actual = bytes.sublist(offset, offset + 4);
                if (!listEquals(actual, sample['rgba'] as List)) {
                  differences.add(
                    'grain opacity=${diagnostic['opacity']} ${sample['x']},${sample['y']}: $actual / ${sample['rgba']}',
                  );
                }
              }
            } finally {
              image.dispose();
              picture.dispose();
            }
          }
        }
        now = (row['at'] as num).toDouble();
        frames.tick();
        final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
        paper.paint(canvas, const ui.Size(120, 216));
        canvas.translate(0, 48);
        ground.paint(canvas, const ui.Size(120, 80));
        final picture = recorder.endRecording(),
            image = await picture.toImage(120, 216);
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
                    (((sample['y'] as int) + 48) * 120 + (sample['x'] as int)) *
                    4,
                actual = bytes.sublist(offset, offset + 4);
            if (!listEquals(actual, sample['rgba'] as List)) {
              differences.add(
                'custom=$custom at=$now ${sample['x']},${sample['y']}: $actual / ${sample['rgba']}',
              );
            }
          }
        } finally {
          image.dispose();
          picture.dispose();
        }
      } finally {
        ground.removeListener(changed);
        ground.dispose();
        paper.dispose();
        entrance.dispose();
        frames.dispose();
      }
    }
    expect(differences, isEmpty, reason: differences.join('\n'));
  } finally {
    program.dispose();
    paperProgram.dispose();
  }
}

class _GroundFrames extends ChangeNotifier {
  void tick() => notifyListeners();
}
