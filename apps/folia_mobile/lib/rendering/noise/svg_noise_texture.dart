import 'dart:ui' as ui;

import 'native_svg_noise.dart';
import 'svg_noise_image.dart';

ui.ColorFilter svgPaperGrainFilter(bool whiteInk) {
  final ink = whiteInk ? 255.0 : 0.0;
  return ui.ColorFilter.matrix([
    0,
    0,
    0,
    0,
    ink,
    0,
    0,
    0,
    0,
    ink,
    0,
    0,
    0,
    0,
    ink,
    .12,
    0,
    0,
    0,
    -.03 * 255,
  ]);
}

// The source SVG renders into a color-managed intermediate, then applies rect opacity. Keeping those stages separate matters at low alpha; prepare the static full-DPR texture once, never in a frame callback.
Future<ui.Image> prepareSvgNoiseTexture({
  required NativeSvgNoise native,
  required SvgNoiseRecipe recipe,
  required double cssExtent,
  required double dpr,
  bool whiteInk = false,
}) async {
  final raw = await decodeSvgNoise(
    await native.create(recipe, cssExtent: cssExtent, dpr: dpr),
  );
  final recorder = ui.PictureRecorder(),
      canvas = ui.Canvas(recorder),
      paint = ui.Paint();
  if (recipe == SvgNoiseRecipe.paper) {
    paint.colorFilter = svgPaperGrainFilter(whiteInk);
  } else {
    paint.colorFilter = const ui.ColorFilter.linearToSrgbGamma();
  }
  if (recipe == SvgNoiseRecipe.wall) {
    canvas.saveLayer(
      ui.Offset.zero & ui.Size(raw.width.toDouble(), raw.height.toDouble()),
      ui.Paint()
        ..color = const ui.Color.from(alpha: .55, red: 1, green: 1, blue: 1),
    );
  }
  canvas.drawImage(raw, ui.Offset.zero, paint);
  if (recipe == SvgNoiseRecipe.wall) canvas.restore();
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(raw.width, raw.height);
  } finally {
    picture.dispose();
    raw.dispose();
  }
}
