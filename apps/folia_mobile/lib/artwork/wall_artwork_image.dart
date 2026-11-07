import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'wall_artwork_effect.dart';
import 'wall_image_subscription.dart';

// Image frames update a retained native leaf. Optional background layers share one effect, preserving filter-after-composition semantics without bitmap/widget/channel copies.
class WallArtworkImage extends LeafRenderObjectWidget {
  const WallArtworkImage({
    super.key,
    required this.provider,
    this.underlay,
    this.effect,
  });
  final ImageProvider<String>? provider, underlay;
  final WallArtworkEffect? effect;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderWallArtworkImage(
        provider,
        createLocalImageConfiguration(context),
        TickerMode.valuesOf(context).enabled,
        effect,
        underlay,
      );
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderWallArtworkImage renderObject,
  ) => renderObject.update(
    provider,
    createLocalImageConfiguration(context),
    TickerMode.valuesOf(context).enabled,
    effect,
    underlay,
  );
}

class RenderWallArtworkImage extends RenderImage {
  RenderWallArtworkImage(
    this._provider,
    this._configuration,
    this._active, [
    this._effect,
    this._underlay,
  ]) : super(
         fit: BoxFit.cover,
         alignment: Alignment.center,
         filterQuality: FilterQuality.low,
       );
  ImageProvider<String>? _provider, _underlay;
  ImageConfiguration _configuration;
  bool _active, _effectListening = false;
  WallArtworkEffect? _effect;
  ui.Image? _underlayImage;
  late final _primary = WallImageSubscription(
        onImage: _imageReady,
        onClear: _clearImage,
      ),
      _background = WallImageSubscription(
        onImage: _underlayReady,
        onClear: _clearUnderlay,
      );
  void update(
    ImageProvider<String>? provider,
    ImageConfiguration configuration,
    bool active,
    WallArtworkEffect? effect, [
    ImageProvider<String>? underlay,
  ]) {
    if (!identical(effect, _effect)) {
      if (_effectListening) _effect?.removeListener(_effectChanged);
      _effectListening = false;
      _effect = effect;
      _effect?.imageChanged(image);
      _effect?.underlayChanged(_underlayImage);
      markNeedsPaint();
    }
    _provider = provider;
    _underlay = underlay;
    _configuration = configuration;
    _active = active;
    _sync();
  }

  void _imageReady(ImageInfo info) {
    image = info.image.clone();
    scale = info.scale;
    _effect?.imageChanged(image);
    info.dispose();
  }

  void _clearImage() {
    image = null;
    _effect?.imageChanged(null);
  }

  void _underlayReady(ImageInfo info) {
    _underlayImage?.dispose();
    _underlayImage = info.image.clone();
    info.dispose();
    _effect?.underlayChanged(_underlayImage);
    markNeedsPaint();
  }

  void _clearUnderlay() {
    _underlayImage?.dispose();
    _underlayImage = null;
    _effect?.underlayChanged(null);
    markNeedsPaint();
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
    final enabled = _active && (_effect?.needsImage ?? true);
    _primary.update(_provider, _configuration, enabled: enabled);
    _background.update(_underlay, _configuration, enabled: enabled);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _primary.setAttached(true);
    _background.setAttached(true);
    _sync();
  }

  @override
  void detach() {
    if (_effectListening) _effect?.removeListener(_effectChanged);
    _effectListening = false;
    _primary.setAttached(false);
    _background.setAttached(false);
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
    _primary.dispose();
    _background.dispose();
    _effect?.imageChanged(null);
    _effect?.underlayChanged(null);
    _underlayImage?.dispose();
    _underlayImage = null;
    super.dispose();
  }
}
