import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'wall_artwork_effect.dart';

// Animated image streams update RenderImage directly, not a widget subtree per frame. Hidden retained scenes keep their image without scheduling image frames.
class WallArtworkImage extends LeafRenderObjectWidget {
  const WallArtworkImage({super.key, required this.provider, this.effect});
  final ImageProvider<String>? provider;
  final WallArtworkEffect? effect;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderWallArtworkImage(
        provider,
        createLocalImageConfiguration(context),
        TickerMode.valuesOf(context).enabled,
        effect,
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
      effect,
    );
  }
}

class RenderWallArtworkImage extends RenderImage {
  RenderWallArtworkImage(
    this._provider,
    this._configuration,
    this._active, [
    this._effect,
  ]) : super(
         fit: BoxFit.cover,
         alignment: Alignment.center,
         filterQuality: FilterQuality.low,
       );
  ImageProvider<String>? _provider;
  ImageConfiguration _configuration;
  bool _active, _listening = false;
  WallArtworkEffect? _effect;
  bool _effectListening = false;
  ImageStream? _stream;
  ImageStreamCompleterHandle? _keepAlive;
  late final _listener = ImageStreamListener(
    _imageReady,
    onError: _imageFailed,
  );
  void update(
    ImageProvider<String>? provider,
    ImageConfiguration configuration,
    bool active,
    WallArtworkEffect? effect,
  ) {
    if (!identical(effect, _effect)) {
      if (_effectListening) _effect?.removeListener(_effectChanged);
      _effectListening = false;
      _effect = effect;
      _effect?.imageChanged(image);
      markNeedsPaint();
    }
    final changed = provider != _provider || configuration != _configuration;
    _provider = provider;
    _configuration = configuration;
    _active = active;
    if (changed) {
      _forget();
      image = null;
      _effect?.imageChanged(null);
    }
    _sync();
  }

  void _imageReady(ImageInfo info, bool synchronous) {
    // RenderImage owns this clone; the stream callback's ImageInfo is always released separately.
    image = info.image.clone();
    _effect?.imageChanged(image);
    scale = info.scale;
    info.dispose();
  }

  void _imageFailed(Object error, StackTrace? stack) {
    image = null;
    _effect?.imageChanged(null);
  }

  void _effectChanged() {
    _sync();
    markNeedsPaint();
  }

  void _sync() {
    final effectWanted = attached && _active && _effect != null;
    if (effectWanted != _effectListening) {
      _effectListening = effectWanted;
      if (effectWanted) {
        _effect!.addListener(_effectChanged);
      } else {
        _effect?.removeListener(_effectChanged);
      }
    }
    if (!attached || !_active || !(_effect?.needsImage ?? true)) {
      if (_listening) {
        _keepAlive = _stream!.completer?.keepAlive();
        _stream!.removeListener(_listener);
        _listening = false;
      }
      return;
    }
    if (_provider == null) return;
    _stream ??= _provider!.resolve(_configuration);
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
    if (_effectListening) _effect?.removeListener(_effectChanged);
    _effectListening = false;
    if (_listening) {
      _keepAlive = _stream!.completer?.keepAlive();
      _stream!.removeListener(_listener);
      _listening = false;
    }
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_effect == null) {
      super.paint(context, offset);
      return;
    }
    if (!size.isEmpty) _effect!.paint(context.canvas, offset, size, image);
  }

  @override
  void dispose() {
    if (_effectListening) _effect?.removeListener(_effectChanged);
    _effectListening = false;
    _forget();
    super.dispose();
  }
}
