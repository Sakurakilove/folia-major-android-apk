import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'native_svg_noise.dart';
import 'svg_noise_texture.dart';
import 'svg_noise_image.dart';

// One-frame image streams share the normal bounded image cache and coalesce concurrent static texture jobs. Live leases pin full-resolution images without owning an animation clock.
class SvgNoiseKey {
  const SvgNoiseKey(
    this.path,
    this.recipe,
    this.extent,
    this.dpr,
    this.whiteInk,
    this.raw,
  );
  final String path;
  final SvgNoiseRecipe recipe;
  final double extent, dpr;
  final bool whiteInk, raw;
  @override
  bool operator ==(Object other) =>
      other is SvgNoiseKey &&
      path == other.path &&
      recipe == other.recipe &&
      extent == other.extent &&
      dpr == other.dpr &&
      whiteInk == other.whiteInk &&
      raw == other.raw;
  @override
  int get hashCode => Object.hash(path, recipe, extent, dpr, whiteInk, raw);
}

class SvgNoiseProvider extends ImageProvider<SvgNoiseKey> {
  SvgNoiseProvider({
    required NativeSvgNoise native,
    required SvgNoiseRecipe recipe,
    required double cssExtent,
    required double dpr,
    bool whiteInk = false,
    bool raw = false,
  }) : key = SvgNoiseKey(
         native.path,
         recipe,
         cssExtent,
         dpr,
         raw ? false : whiteInk,
         raw,
       );
  final SvgNoiseKey key;
  @override
  Future<SvgNoiseKey> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(key);
  @override
  ImageStreamCompleter loadImage(
    SvgNoiseKey key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_prepare(key));
  Future<ImageInfo> _prepare(SvgNoiseKey key) async => ImageInfo(
    image: key.raw
        ? await decodeSvgNoise(
            await NativeSvgNoise(libraryPath: key.path)
                .create(key.recipe, cssExtent: key.extent, dpr: key.dpr),
          )
        : await prepareSvgNoiseTexture(
            native: NativeSvgNoise(libraryPath: key.path),
            recipe: key.recipe,
            cssExtent: key.extent,
            dpr: key.dpr,
            whiteInk: key.whiteInk,
          ),
    scale: key.dpr,
  );
}

class SvgNoiseImageLease extends ChangeNotifier
    implements ValueListenable<ui.Image?> {
  SvgNoiseImageLease(SvgNoiseProvider provider) {
    _stream = provider.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener(_accept, onError: _failed);
    _stream.addListener(_listener);
  }
  late final ImageStream _stream;
  late final ImageStreamListener _listener;
  ui.Image? _image;
  Object? error;
  StackTrace? errorStack;
  bool _closed = false;
  @override
  ui.Image? get value => _image;
  void _accept(ImageInfo info, bool synchronous) {
    try {
      if (_closed) return;
      final previous = _image;
      _image = info.image.clone();
      previous?.dispose();
      notifyListeners();
    } finally {
      info.dispose();
    }
  }

  void _failed(Object error, StackTrace? stack) {
    if (!_closed) {
      this.error = error;
      errorStack = stack;
      notifyListeners();
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Folia SVG material',
        ),
      );
    }
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _stream.removeListener(_listener);
    _image?.dispose();
    _image = null;
    super.dispose();
  }
}
