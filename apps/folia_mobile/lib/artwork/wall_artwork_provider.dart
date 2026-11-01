part of 'wall_artwork_store.dart';

// Priming consumes the first decode slot and preserves the underlying codec's full frame sequence, durations and repetition. Browser decoder parity still requires comparison.
class _PrimedArtworkCodec implements ui.Codec {
  _PrimedArtworkCodec(this._codec, this._first);
  final ui.Codec _codec;
  ui.FrameInfo? _first;
  bool _closed = false;
  @override
  int get frameCount => _codec.frameCount;
  @override
  int get repetitionCount => _codec.repetitionCount;
  @override
  Future<ui.FrameInfo> getNextFrame() {
    if (_closed) throw StateError('Artwork codec is closed');
    final first = _first;
    if (first != null) {
      _first = null;
      return SynchronousFuture(first);
    }
    return _codec.getNextFrame();
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _first?.image.dispose();
    _first = null;
    _codec.dispose();
  }
}

class _WallArtworkCompleter extends MultiFrameImageStreamCompleter {
  _WallArtworkCompleter({required super.codec, required this.onDispose})
    : super(scale: 1);
  final VoidCallback onDispose;
  @override
  void onDisposed() {
    onDispose();
    super.onDisposed();
  }
}

class _WallArtworkProvider extends ImageProvider<String> {
  const _WallArtworkProvider(this.store, this.url);
  final WallArtworkStore store;
  final String url;
  @override
  Future<String> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(url);
  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    String key,
    ImageErrorListener handleError,
  ) {
    stream.setCompleter(store._obtain(key, store.decoder));
  }

  @override
  ImageStreamCompleter loadImage(String key, ImageDecoderCallback decode) =>
      store._obtain(key, store.imageDecoder ?? decode);
  @override
  Future<bool> evict({
    ImageCache? cache,
    ImageConfiguration configuration = ImageConfiguration.empty,
  }) async => (cache ?? store.cache).evict(url);
  @override
  Future<ImageCacheStatus?> obtainCacheStatus({
    required ImageConfiguration configuration,
    ImageErrorListener? handleError,
  }) async => store.cache.statusForKey(url);
  @override
  bool operator ==(Object other) =>
      other is _WallArtworkProvider &&
      identical(store, other.store) &&
      url == other.url;
  @override
  int get hashCode => Object.hash(identityHashCode(store), url);
}
