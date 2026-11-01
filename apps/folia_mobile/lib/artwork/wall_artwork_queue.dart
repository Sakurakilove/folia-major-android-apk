import 'dart:async';
import 'dart:math' as math;

// Original two-slot artwork queue drops abandoned waiting work; a running loader owns cancellation and releases its slot only after it stops.
class ArtworkCancelled implements Exception {
  const ArtworkCancelled();
  @override
  String toString() => 'Artwork request cancelled';
}

class ArtworkCancellation {
  bool _cancelled = false;
  final _listeners = <void Function()>{};
  bool get cancelled => _cancelled;
  void add(void Function() callback) {
    if (_cancelled) {
      callback();
    } else {
      _listeners.add(callback);
    }
  }

  void remove(void Function() callback) => _listeners.remove(callback);
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final listeners = _listeners.toList(growable: false);
    _listeners.clear();
    for (final callback in listeners) {
      callback();
    }
  }

  void throwIfCancelled() {
    if (_cancelled) throw const ArtworkCancelled();
  }
}

class _ArtworkJob {
  const _ArtworkJob(this.run, this.cancel);
  final void Function() run, cancel;
}

class WallArtworkQueue {
  WallArtworkQueue({int concurrency = 2, this.maxWaiting = 256})
    : concurrency = math.max(1, concurrency);
  final int concurrency, maxWaiting;
  int _active = 0;
  bool _closed = false;
  final _waiting = <_ArtworkJob>[];
  int get activeCount => _active;
  int get waitingCount => _waiting.length;
  Future<T> schedule<T>(
    Future<T> Function() task, {
    ArtworkCancellation? signal,
  }) {
    final completer = Completer<T>();
    var started = false;
    late _ArtworkJob job;
    void cancel() {
      if (started || completer.isCompleted) return;
      _waiting.remove(job);
      signal?.remove(cancel);
      completer.completeError(const ArtworkCancelled());
    }

    Future<void> run() async {
      signal?.remove(cancel);
      if (signal?.cancelled ?? false) {
        completer.completeError(const ArtworkCancelled());
        return;
      }
      started = true;
      _active++;
      try {
        completer.complete(await Future<T>.microtask(task));
      } catch (error, stack) {
        completer.completeError(error, stack);
      } finally {
        _active--;
        if (_waiting.isNotEmpty) _waiting.removeAt(0).run();
      }
    }

    job = _ArtworkJob(() => unawaited(run()), cancel);
    if (_closed || (signal?.cancelled ?? false)) {
      completer.completeError(const ArtworkCancelled());
    } else if (_active < concurrency) {
      job.run();
    } else if (_waiting.length < maxWaiting) {
      _waiting.add(job);
      signal?.add(cancel);
    } else {
      completer.completeError(const ArtworkCancelled());
    }
    return completer.future;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final job in _waiting.toList(growable: false)) {
      job.cancel();
    }
  }
}
