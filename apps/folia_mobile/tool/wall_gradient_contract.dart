import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/tiles/artwork/bravais_art_program.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_card_palette.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_card_look.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_item.dart';
import 'package:folia_mobile/library/bravais/seam/appearance/bravais_seam_look.dart';
import 'package:folia_mobile/library/bravais/seam/bravais_seam_level.dart';

// One existing shader check samples modern interpolation, premultiplied fade and the actual original wall tint. This is not full gradient/gamut/device pixel acceptance.
Future<void> checkWallGradient(BravaisArtProgram program) async {
  final reference = jsonDecode(
    File('test/fixtures/wall_gradient_reference.json').readAsStringSync(),
  );
  const palette = BravaisCardPalette(
    background: ui.Color(0xff070707),
    ink: ui.Color(0xfff7f4ee),
    accent: ui.Color(0xfffd5c47),
    secondary: ui.Color(0xff6a48ff),
    daylight: false,
  );
  for (final row in reference['posterCases']) {
    final flags = row['flags'],
        kind = BravaisTileKind.values.byName(flags['kind'] ?? 'content'),
        look = BravaisCardLook(
          face: BravaisCardFace(
            kind == BravaisTileKind.wall || kind == BravaisTileKind.window
                ? null
                : BravaisItem(
                    key: 'p',
                    kind: BravaisItemKind.track,
                    title: '',
                    subtitle: '',
                    badge: '',
                    dimmed: flags['dimmed'] ?? false,
                    unavailable: flags['unavailable'] ?? false,
                    selected: flags['selected'] ?? false,
                  ),
            kind,
          ),
          palette: palette,
          width: 136,
          height: 128,
          posterWall: true,
          current: flags['current'] ?? false,
          focused: flags['focused'] ?? false,
          expanded: flags['expanded'] ?? false,
          linked: flags['linked'] ?? false,
        );
    expect(
      look.filter.operations.isEmpty
          ? 'none'
          : look.filter.operations
                .map((op) => '${op.kind.name}(${op.amount})')
                .join(' '),
      row['filter'],
    );
    expect(look.faceInset, row['inset']);
    expect(look.posterTintOpacity, row['tint']);
  }
  for (final row in reference['seamCases']) {
    final f = row['flags'],
        p = BravaisCardPalette(
          background: palette.background,
          ink: palette.ink,
          accent: palette.accent,
          secondary: palette.secondary,
          daylight: f['daylight'] ?? false,
          tintIntensity: (f['tintIntensity'] as num?)?.toDouble() ?? .5,
        ),
        look = BravaisSeamLook(
          palette: p,
          variant: BravaisSeamVariant.values.byName(f['variant'] ?? 'full'),
          tinted: f['tinted'] ?? true,
          lightsOut: f['lightsOut'] ?? false,
          wallClear: f['wallClear'] ?? false,
          clearSeam: f['clearSeam'] ?? false,
          menuOpen: f['menuOpen'] ?? false,
          keyboardWindow: f['keyboardWindow'] ?? false,
        );
    expect(look.paperTint, closeTo(row['paperTint'], 1e-6), reason: '$f paper');
    expect(
      look.textTint,
      closeTo(row['textTint'], 1e-6),
      reason: '$f foreground',
    );
    expect(look.bodyOpacity, row['bodyOpacity'], reason: '$f body');
  }
  final gradient = program.gradients.createLinear();
  Future<List<int>> sample(List<ui.Color> colors, double degrees) async {
    final recorder = ui.PictureRecorder();
    gradient.paint(
      ui.Canvas(recorder),
      const ui.Rect.fromLTWH(0, 0, 3, 1),
      degrees,
      colors,
    );
    final picture = recorder.endRecording(),
        image = await picture.toImage(3, 1);
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!;
      return bytes.buffer.asUint8List(bytes.offsetInBytes + 4, 4).toList();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }

  try {
    final samples = [
      await sample(const [ui.Color(0xffff0000), ui.Color(0xff0000ff)], 90),
      await sample(const [ui.Color(0xffff0000), ui.Color(0x00000000)], 90),
      await sample(
        const BravaisCardPalette(
          background: ui.Color(0xff070707),
          ink: ui.Color(0xfff7f4ee),
          accent: ui.Color(0xfffd5c47),
          secondary: ui.Color(0xff6a48ff),
          daylight: false,
        ).tintColors,
        145,
      ),
    ];
    for (var i = 0; i < samples.length; i++) {
      final expected = reference['pixels'][[1, 3, 4][i]];
      for (var channel = 0; channel < 4; channel++) {
        expect(samples[i][channel], closeTo(expected[channel], 1));
      }
    }
  } finally {
    gradient.dispose();
  }
}
