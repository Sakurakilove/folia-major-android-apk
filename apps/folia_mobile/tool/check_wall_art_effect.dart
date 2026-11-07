import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/artwork/wall_image_pixels.dart';
import 'package:folia_mobile/library/bravais/bravais_album_art.dart';
import 'package:folia_mobile/library/bravais/tiles/artwork/bravais_art_effect.dart';
import 'package:folia_mobile/library/bravais/tiles/artwork/bravais_art_program.dart';
import 'package:folia_mobile/library/bravais/tiles/artwork/bravais_art_style.dart';

import 'wall_art_math_contract.dart';
import 'wall_art_motion_contract.dart';
import 'wall_art_leaf_contract.dart';

// Native shader/owner/metadata check only; GPU/browser final pixel equality is a separate migration gate.
Future<void> checkWallArtEffect(WidgetTester tester) async {
  final owned = await tester.runAsync(() async {
    await checkWallArtMath();
    checkWallArtMotion();
    final program = await BravaisArtProgram.load(),
        style = ValueNotifier(
          const BravaisArtStyle(
            mode: BravaisArtShaderMode.artist,
            light: ui.Color.from(alpha: 1, red: .8, green: .6, blue: .4),
            dark: ui.Color.from(alpha: 1, red: .1, green: .1, blue: .1),
            grayscale: 1,
            contrast: 1.15,
            brightness: 1.05,
            multiply: true,
            darkOpacity: 1,
          ),
        ),
        effect = BravaisArtEffect(program, style);
    final recorder = ui.PictureRecorder();
    ui.Canvas(
      recorder,
    ).drawColor(const ui.Color.fromARGB(255, 100, 150, 200), ui.BlendMode.src);
    final picture = recorder.endRecording(),
        image = await picture.toImage(1, 1);
    picture.dispose();
    Future<List<int>> draw(ui.Image image, int width) async {
      final recorder = ui.PictureRecorder();
      effect.paint(
        ui.Canvas(recorder),
        ui.Offset.zero,
        ui.Size(width.toDouble(), 1),
        image,
      );
      final picture = recorder.endRecording(),
          output = await picture.toImage(width, 1);
      try {
        final bytes = (await output.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!;
        return bytes.buffer
            .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes)
            .toList();
      } finally {
        picture.dispose();
        output.dispose();
      }
    }

    final artist = await draw(image, 1);
    for (var i = 0; i < 4; i++) {
      expect(artist[i], closeTo([122, 92, 61, 255][i], 1));
    }
    final provider = _SampleImage(image), permissions = <bool>[];
    final sampler = WallImagePixelSampler(
      provider: (_, {required anonymous}) {
        permissions.add(anonymous);
        return provider;
      },
      canRead: (_) async => true,
    );
    final pixels = await sampler.sample('test://image');
    expect(pixels.status, WallPixelStatus.ready);
    expect(pixels.pixels!.length, 50 * 50 * 4);
    expect(pixels.pixels!.take(4), [100, 150, 200, 255]);
    expect(permissions, [true]);
    final blocked = await WallImagePixelSampler(
      provider: (_, {required anonymous}) => provider,
      canRead: (_) async => false,
    ).sample('test://blocked');
    expect(blocked.status, WallPixelStatus.unreadable);
    expect(blocked.pixels, isNull);
    final tiledRecorder = ui.PictureRecorder(),
        canvas = ui.Canvas(tiledRecorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 1, 1),
      ui.Paint()..color = const ui.Color(0xffff0000),
    );
    canvas.drawRect(
      const ui.Rect.fromLTWH(1, 0, 1, 1),
      ui.Paint()..color = const ui.Color(0xff0000ff),
    );
    final tiledPicture = tiledRecorder.endRecording(),
        tiled = await tiledPicture.toImage(2, 1);
    tiledPicture.dispose();
    style.value = const BravaisArtStyle(
      mode: BravaisArtShaderMode.mosaic,
      placement: BravaisArtPlacement(2, 0, 0),
    );
    expect(
      await draw(tiled, 8),
      List.generate(
        8,
        (i) => i.isEven ? [255, 0, 0, 255] : [0, 0, 255, 255],
      ).expand((e) => e).toList(),
    );
    Future<ui.Image> half(bool white) async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(
        white ? const ui.Color(0x80ffffff) : const ui.Color(0x80000000),
        ui.BlendMode.src,
      );
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(1, 1);
      } finally {
        picture.dispose();
      }
    }

    final white = await half(true), black = await half(false);
    effect.underlayChanged(black);
    style.value = const BravaisArtStyle(
      mode: BravaisArtShaderMode.mosaic,
      grayscale: 1,
      contrast: 2.2,
      brightness: 1.3,
    );
    final composited = await draw(white, 1);
    expect(composited.take(3), [255, 255, 255]);
    expect(composited[3], closeTo(192, 1));
    effect.underlayChanged(null);
    white.dispose();
    black.dispose();
    // Closing the host does not invalidate a still-retained shader's sampler fallback.
    program.dispose();
    style.value = const BravaisArtStyle(
      mode: BravaisArtShaderMode.mosaic,
      fallback: true,
      fallbackColors: [ui.Color(0xff00ff00), ui.Color(0xff00ff00)],
    );
    final fallbackRecorder = ui.PictureRecorder();
    effect.paint(
      ui.Canvas(fallbackRecorder),
      ui.Offset.zero,
      const ui.Size(1, 1),
      null,
    );
    fallbackRecorder.endRecording().dispose();
    return (effect: effect, style: style, image: image, tiled: tiled);
  });
  if (owned == null) return;
  await checkWallArtLeaf(
    tester,
    foreground: owned.image,
    background: owned.tiled,
    effect: owned.effect,
    style: owned.style,
  );
  owned.effect.dispose();
  owned.style.dispose();
  owned.image.dispose();
  owned.tiled.dispose();
}

class _SampleImage extends ImageProvider<int> {
  const _SampleImage(this.image);
  final ui.Image image;
  @override
  Future<int> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(identityHashCode(this));
  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    int key,
    ImageErrorListener handleError,
  ) => stream.setCompleter(
    OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: image.clone())),
    ),
  );
}
