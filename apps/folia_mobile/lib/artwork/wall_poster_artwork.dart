import 'dart:async';

import 'package:flutter/widgets.dart';

import 'wall_artwork_queue.dart';
import 'wall_artwork_store.dart';
import 'wall_artwork_image.dart';

// Original poster variant handoff: keep decoded lower gear while upgrading, wait one second before Android downsizing, and never fade or replay the card.
class WallPosterArtwork extends ValueNotifier<String> {
  WallPosterArtwork(this.store, String? cover, double sizePx)
    : _source = cover ?? '',
      _step = wallArtworkStep(sizePx),
      _ready = store.pickDisplay(cover ?? '', wallArtworkStep(sizePx)),
      super('') {
    _effect();
  }
  final WallArtworkStore store;
  String _source;
  double _step;
  PosterArtwork _ready;
  ArtworkCancellation? _cancel;
  Timer? _downgrade;
  int _generation = 0;
  bool _closed = false, _active = true;
  void update(String? cover, double sizePx) {
    if (_closed) return;
    final source = cover ?? '', step = wallArtworkStep(sizePx);
    if (_source == source && _step == step) return;
    _source = source;
    _step = step;
    _effect();
  }

  void _interrupt() {
    _generation++;
    _downgrade?.cancel();
    _downgrade = null;
    _cancel?.cancel();
    _cancel = null;
  }

  void _effect() {
    _interrupt();
    final current = _ready.cover == _source
        ? _ready
        : store.pickDisplay(_source, _step);
    value = current.url;
    if (!_active || _source.isEmpty) return;
    final cancel = ArtworkCancellation(),
        generation = _generation,
        source = _source,
        step = _step;
    _cancel = cancel;
    if (current.step == step) {
      if (!store.decoded(current.url) || !store.hasDecodedOwner(current.url)) {
        unawaited(store.decodeVariant(current.url, signal: cancel));
      }
      return;
    }
    final url = store.variant(source, step);
    void load() {
      _downgrade = null;
      unawaited(
        store.decodeVariant(url, signal: cancel).then((decoded) {
          if (!decoded || _closed || !_active || generation != _generation) {
            return;
          }
          _ready = PosterArtwork(source, step, url);
          _effect();
        }),
      );
    }

    if (current.step > step) {
      _downgrade = Timer(const Duration(seconds: 1), load);
    } else {
      load();
    }
  }

  void setActive(bool active) {
    if (_closed || active == _active) return;
    _active = active;
    _effect();
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _interrupt();
    super.dispose();
  }
}

class WallPosterImage extends StatelessWidget {
  const WallPosterImage({super.key, required this.artwork, this.fallback});
  final WallPosterArtwork artwork;
  final Widget? fallback;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: artwork,
    builder: (context, url, _) => url.isEmpty
        ? fallback ?? const SizedBox()
        : RepaintBoundary(
            child: WallArtworkImage(provider: artwork.store.provider(url)),
          ),
  );
}
