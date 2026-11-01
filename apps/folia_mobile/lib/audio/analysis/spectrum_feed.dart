import 'dart:async';

import '../../platform/android_host.dart';
import 'spectrum_reader.dart';
import 'spectrum_snapshot.dart';

// One frame-owner sample feeds all consumers; leases and playback/visibility edges alone cross MethodChannel.
class SpectrumFeed {
  SpectrumFeed({this.onError});
  final void Function(Object)? onError;
  final snapshot = SpectrumSnapshot();
  final _consumers = <Object>{};
  SpectrumReader? _reader;
  bool _playing = false,
      _foreground = true,
      _applied = false,
      _syncing = false,
      _closed = false;
  bool get _wanted =>
      !_closed && _foreground && _playing && _consumers.isNotEmpty;
  bool get hasVisibleConsumers =>
      !_closed && _foreground && _consumers.isNotEmpty;
  Object? error;

  void Function() acquire() {
    final token = Object();
    if (_closed) return () {};
    _consumers.add(token);
    _activation();
    var released = false;
    return () {
      if (released) return;
      released = true;
      _consumers.remove(token);
      _activation();
    };
  }

  void setPlaying(bool playing) {
    if (_playing == playing || _closed) return;
    _playing = playing;
    _activation();
  }

  void setForeground(bool foreground) {
    if (_foreground == foreground || _closed) return;
    _foreground = foreground;
    _activation();
  }

  void _activation() {
    if (_wanted && _reader == null) {
      try {
        _reader = SpectrumReader.open();
        error = null;
      } catch (failure) {
        error = failure;
        onError?.call(failure);
      }
    }
    unawaited(_syncControl());
  }

  Future<void> _syncControl() async {
    if (_syncing) return;
    _syncing = true;
    try {
      while (_applied != (_wanted && _reader != null)) {
        final next = _wanted && _reader != null;
        try {
          await AndroidHost.command('setSpectrumEnabled', {'enabled': next});
          _applied = next;
        } catch (failure) {
          error = failure;
          if (!_closed) onError?.call(failure);
          break; // Retry on a new lifecycle/consumer edge, never on every visual frame.
        }
      }
    } finally {
      _syncing = false;
    }
  }

  void sample(double wallClockMs) {
    if (!hasVisibleConsumers) return;
    if (!_playing) {
      snapshot.idle(wallClockMs);
      return;
    }
    if (_applied) _reader?.sample(snapshot);
  }

  void onFrame() {
    if (hasVisibleConsumers) {
      sample(DateTime.now().millisecondsSinceEpoch.toDouble());
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _consumers.clear();
    _reader?.close();
    _reader = null;
    unawaited(_syncControl());
  }
}
