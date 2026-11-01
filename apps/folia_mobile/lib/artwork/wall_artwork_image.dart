import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// Animated image streams update RenderImage directly, not a widget subtree per frame. Hidden retained scenes keep their image without scheduling image frames.
class WallArtworkImage extends LeafRenderObjectWidget {
  const WallArtworkImage({super.key, required this.provider});
  final ImageProvider<String> provider;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderWallArtworkImage(
        provider,
        createLocalImageConfiguration(context),
        TickerMode.valuesOf(context).enabled,
      );
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderWallArtworkImage renderObject,
  ) {
    renderObject.update(
      provider,
      createLocalImageConfiguration(context),
      TickerMode.valuesOf(context).enabled,
    );
  }
}

class RenderWallArtworkImage extends RenderImage {
  RenderWallArtworkImage(this._provider, this._configuration, this._active)
    : super(
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.low,
      );
  ImageProvider<String> _provider;
  ImageConfiguration _configuration;
  bool _active, _listening = false;
  ImageStream? _stream;
  ImageStreamCompleterHandle? _keepAlive;
  late final _listener = ImageStreamListener(
    _imageReady,
    onError: _imageFailed,
  );
  void update(
    ImageProvider<String> provider,
    ImageConfiguration configuration,
    bool active,
  ) {
    final changed = provider != _provider || configuration != _configuration;
    _provider = provider;
    _configuration = configuration;
    _active = active;
    if (changed) {
      _forget();
      image = null;
    }
    _sync();
  }

  void _imageReady(ImageInfo info, bool synchronous) {
    // RenderImage owns this clone; the stream callback's ImageInfo is always released separately.
    image = info.image.clone();
    scale = info.scale;
    info.dispose();
  }

  void _imageFailed(Object error, StackTrace? stack) {
    image = null;
  }

  void _sync() {
    if (!attached || !_active) {
      if (_listening) {
        _keepAlive = _stream!.completer?.keepAlive();
        _stream!.removeListener(_listener);
        _listening = false;
      }
      return;
    }
    _stream ??= _provider.resolve(_configuration);
    if (!_listening) {
      _listening = true;
      _stream!.addListener(_listener);
      _keepAlive?.dispose();
      _keepAlive = null;
    }
  }

  void _forget() {
    if (_listening) _stream?.removeListener(_listener);
    _listening = false;
    _keepAlive?.dispose();
    _keepAlive = null;
    _stream = null;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _sync();
  }

  @override
  void detach() {
    if (_listening) {
      _keepAlive = _stream!.completer?.keepAlive();
      _stream!.removeListener(_listener);
      _listening = false;
    }
    super.detach();
  }

  @override
  void dispose() {
    _forget();
    super.dispose();
  }
}
