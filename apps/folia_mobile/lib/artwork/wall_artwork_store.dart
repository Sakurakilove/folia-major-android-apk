import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'cover_url.dart';
import 'wall_artwork_queue.dart';

part 'wall_artwork_provider.dart';
part 'wall_artwork_decode.dart';

// The wall owns its decoded-image budget separately from other pages. Live visible images stay pinned by their streams at full source resolution.
typedef WallArtworkBufferLoader = Future<ui.ImmutableBuffer> Function(
  String url,
  ArtworkCancellation signal,
);

class PosterArtwork {
  const PosterArtwork(this.cover, this.step, this.url);
  final String cover, url;
  final double step;
}

class _ArtworkDecode {
  final signal = ArtworkCancellation(), ready = Completer<bool>();
  late final Future<ui.Codec> codec;
  int consumers = 0;
  bool finished = false, timedOut = false;
}

class WallArtworkStore {
  WallArtworkStore({
    required this.policy,
    required this.loadBuffer,
    this.imageDecoder,
    int Function()? nowMs,
  }) : nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch) {
    cache
      ..maximumSize = 600
      ..maximumSizeBytes = 24 * 1024 * 1024;
  }
  final CoverUrlPolicy policy;
  final WallArtworkBufferLoader loadBuffer;
  final ImageDecoderCallback? imageDecoder;
  ImageDecoderCallback get decoder =>
      imageDecoder ?? PaintingBinding.instance.instantiateImageCodecWithSize;
  final int Function() nowMs;
  final cache = ImageCache(), queue = WallArtworkQueue();
  final _decoded = <String, bool>{},
      _failed = <String, int>{},
      _jobs = <String, _ArtworkDecode>{};
  bool _closed = false;
  bool decoded(String url) => _decoded.containsKey(url);
  bool hasDecodedOwner(String url) {
    final status = cache.statusForKey(url);
    return decoded(url) && (status.keepAlive || status.live);
  }

  bool failedRecently(String url) {
    final until = _failed[url];
    if (until == null) return false;
    if (nowMs() < until) return true;
    _failed.remove(url);
    return false;
  }

  void _remember(String url) {
    _decoded.remove(url);
    _decoded[url] = true;
    while (_decoded.length > 600) {
      _decoded.remove(_decoded.keys.first);
    }
  }

  String variant(String cover, double step) =>
      step.isFinite ? policy.sized(cover, step) : policy.original(cover);
  PosterArtwork pickDisplay(String cover, double targetStep) {
    final target = variant(cover, targetStep);
    if (decoded(target)) return PosterArtwork(cover, targetStep, target);
    for (final step in coverSizeSteps.reversed) {
      if (step >= targetStep) continue;
      final url = variant(cover, step);
      if (decoded(url)) return PosterArtwork(cover, step, url);
    }
    return PosterArtwork(cover, targetStep, target);
  }

  ImageProvider<String> provider(String url) => _WallArtworkProvider(this, url);
  ImageStreamCompleter _obtain(String url, ImageDecoderCallback decode) {
    final cached = cache.putIfAbsent(
      url,
      () => _create(url, decode),
      onError: (_, _) {},
    );
    if (cached == null) throw StateError('Artwork completer was not created');
    return cached;
  }

  Future<bool> decodeVariant(String url, {ArtworkCancellation? signal}) {
    if (_closed ||
        url.isEmpty ||
        (signal?.cancelled ?? false) ||
        failedRecently(url)) {
      return Future.value(false);
    }
    final existing = _jobs[url];
    if (existing != null && !existing.signal.cancelled) {
      return _lease(existing, signal);
    }
    if (hasDecodedOwner(url)) return Future.value(true);
    if (existing != null && existing.signal.cancelled) cache.evict(url);
    _obtain(url, decoder);
    final job = _jobs[url];
    if (job == null) return Future.value(hasDecodedOwner(url));
    return _lease(job, signal);
  }

  Future<bool> _lease(_ArtworkDecode job, ArtworkCancellation? signal) {
    if (signal?.cancelled ?? false) return Future.value(false);
    job.consumers++;
    var released = false;
    void release() {
      if (released) return;
      released = true;
      job.consumers--;
      if (job.consumers == 0 && !job.finished) job.signal.cancel();
    }

    signal?.add(release);
    return job.ready.future.whenComplete(() {
      signal?.remove(release);
      release();
    });
  }

  void prewarm(String? cover, double sizePx) {
    if (_closed || cover == null || cover.isEmpty) return;
    final url = variant(cover, wallArtworkStep(sizePx));
    if (url.isEmpty || decoded(url) || failedRecently(url)) return;
    unawaited(decodeVariant(url));
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    for (final job in _jobs.values.toList(growable: false)) {
      job.signal.cancel();
    }
    queue.close();
    cache.clear();
    cache.clearLiveImages();
    _decoded.clear();
    _failed.clear();
  }
}

double wallArtworkStep(double sizePx) => resolveCoverSizeStep(
  sizePx.isNaN ? sizePx : sizePx.clamp(double.negativeInfinity, 1024),
);
