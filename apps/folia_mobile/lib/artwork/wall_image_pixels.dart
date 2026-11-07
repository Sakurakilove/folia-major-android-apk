import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

// Pixel access is explicit: native decoding must not silently turn an original CORS fallback into a different artist color or cover fragment.
enum WallPixelStatus { ready, unreadable, unavailable }

class WallPixelSample {
  const WallPixelSample(this.status, [this.pixels]);
  final WallPixelStatus status;
  final Uint8List? pixels;
}

typedef WallSampleProvider = ImageProvider Function(
  String url, {
  required bool anonymous,
});

class WallImagePixelSampler {
  const WallImagePixelSampler({required this.provider, required this.canRead});
  final WallSampleProvider provider;
  final Future<bool> Function(String url) canRead;
  Future<ui.Image> _firstFrame(ImageProvider source) {
    final result = Completer<ui.Image>(),
        stream = source.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!result.isCompleted) result.complete(info.image.clone());
        info.dispose();
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stack) {
        if (!result.isCompleted) result.completeError(error, stack);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return result.future;
  }

  Future<WallPixelSample> sample(String url) async {
    ui.Image? image;
    try {
      image = await _firstFrame(provider(url, anonymous: true));
    } catch (_) {
      // The source retries without crossOrigin to distinguish an unreadable image from an actually broken image.
      try {
        final loaded = await _firstFrame(provider(url, anonymous: false));
        loaded.dispose();
        return const WallPixelSample(WallPixelStatus.unreadable);
      } catch (_) {
        return const WallPixelSample(WallPixelStatus.unavailable);
      }
    }
    try {
      if (!await canRead(url)) {
        return const WallPixelSample(WallPixelStatus.unreadable);
      }
      final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
      // Original loadImagePixels stretches the whole image into exactly 50x50; it does not crop a cover or reduce the displayed artwork.
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        const Rect.fromLTWH(0, 0, 50, 50),
        Paint()..filterQuality = FilterQuality.low,
      );
      final picture = recorder.endRecording();
      ui.Image? sample;
      try {
        sample = await picture.toImage(50, 50);
        final bytes = await sample.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        return bytes == null
            ? const WallPixelSample(WallPixelStatus.unreadable)
            : WallPixelSample(
                WallPixelStatus.ready,
                bytes.buffer.asUint8List(
                  bytes.offsetInBytes,
                  bytes.lengthInBytes,
                ),
              );
      } finally {
        sample?.dispose();
        picture.dispose();
      }
    } catch (_) {
      return const WallPixelSample(WallPixelStatus.unreadable);
    } finally {
      image.dispose();
    }
  }
}
