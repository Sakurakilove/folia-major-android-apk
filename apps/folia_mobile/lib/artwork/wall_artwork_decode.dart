part of 'wall_artwork_store.dart';

// Finite decode jobs own first-frame readiness, cancellation, expiry and codec handoff independently of visible widget rebuilding.
extension _WallArtworkDecoding on WallArtworkStore {
  void _finish(String url, _ArtworkDecode job, bool success) {
    if (job.finished) return;
    if (_closed || job.signal.cancelled) success = false;
    job.finished = true;
    if (success) _remember(url);
    if (identical(_jobs[url], job)) _jobs.remove(url);
    if (!job.ready.isCompleted) job.ready.complete(success);
  }

  ImageStreamCompleter _create(String url, ImageDecoderCallback decode) {
    final job = _ArtworkDecode();
    _jobs[url] = job;
    void evict() {
      cache.evict(url);
    }

    // Cancellation can precede ImageCache registering this new completer; eviction follows its synchronous registration.
    void temporalCancel() {
      scheduleMicrotask(() {
        if (identical(_jobs[url], job)) evict();
      });
    }

    job.signal.add(temporalCancel);
    job.codec = queue.schedule(
      () => _loadCodec(url, job, decode),
      signal: job.signal,
    );
    late final ImageStreamListener listener;
    late final _WallArtworkCompleter completer;
    completer = _WallArtworkCompleter(
      codec: job.codec,
      onDispose: () {
        if (!job.finished) {
          job.signal.cancel();
          _finish(url, job, false);
        }
      },
    );
    listener = ImageStreamListener(
      (image, synchronous) {
        image.dispose();
        _finish(url, job, true);
        completer.removeListener(listener);
      },
      onError: (Object error, StackTrace? stack) {
        if (!_closed && (job.timedOut || error is! ArtworkCancelled)) {
          _failed[url] = nowMs() + 30000;
          while (_failed.length > 600) {
            _failed.remove(_failed.keys.first);
          }
        }
        _finish(url, job, false);
        completer.removeListener(listener);
      },
    );
    completer.addListener(listener);
    return completer;
  }

  Future<ui.Codec> _loadCodec(
    String url,
    _ArtworkDecode job,
    ImageDecoderCallback decode,
  ) async {
    final timer = Timer(const Duration(seconds: 15), () {
      if (!job.signal.cancelled) {
        job.timedOut = true;
        job.signal.cancel();
      }
    });
    ui.Codec? codec;
    ui.FrameInfo? first;
    try {
      job.signal.throwIfCancelled();
      final buffer = await loadBuffer(url, job.signal);
      if (job.signal.cancelled) {
        buffer.dispose();
        throw const ArtworkCancelled();
      }
      codec = await decode(buffer);
      job.signal.throwIfCancelled();
      first = await codec.getNextFrame();
      job.signal.throwIfCancelled();
      return _PrimedArtworkCodec(codec, first);
    } catch (_) {
      first?.image.dispose();
      codec?.dispose();
      rethrow;
    } finally {
      timer.cancel();
    }
  }
}
