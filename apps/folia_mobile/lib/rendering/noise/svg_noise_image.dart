import 'dart:ui' as ui;

import 'native_svg_noise.dart';

// Preserve the SVG RGBA8 intermediate before engine color/opacity operations. The caller owns the returned full-resolution image and the eventual static material texture.
Future<ui.Image> decodeSvgNoise(SvgNoisePixels pixels) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(pixels.bytes);
    descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: pixels.width,
      height: pixels.height,
      rowBytes: pixels.width * 4,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    codec = await descriptor.instantiateCodec();
    return (await codec.getNextFrame()).image;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
    pixels.dispose();
  }
}
