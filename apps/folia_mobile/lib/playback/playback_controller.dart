import 'dart:async';

import 'package:flutter/foundation.dart';

import '../platform/android_host.dart';
import '../lyrics/lyric_document.dart';

// Discrete application state and monotonic interpolation are separate: frames never rebuild the app.
class AudioTrack {
  AudioTrack(this.uri, this.title, this.artist, this.coverPath);
  final String uri, title, artist;
  final String? coverPath;
  factory AudioTrack.fromMap(Map<String, dynamic> data) => AudioTrack(
    data['uri'] as String,
    data['title'] as String? ?? '',
    data['artist'] as String? ?? '',
    data['coverPath'] as String?,
  );
}

class PlaybackController extends ChangeNotifier {
  final clock = Stopwatch()..start();
  StreamSubscription<dynamic>? _subscription;
  List<AudioTrack> tracks = [];
  final Map<String, LyricDocument> _lyrics = {};
  int currentIndex = -1;
  double _position = 0, _anchor = 0, duration = 0, rate = 1;
  double? _nativeOffsetMs, _lastNativeSampleMs;
  bool playing = false;
  bool _closed = false;
  void _notify() {
    if (!_closed) super.notifyListeners();
  }

  String? error;
  String? _requestedUri, _lastNativeUri;
  AudioTrack? get track => currentIndex >= 0 && currentIndex < tracks.length
      ? tracks[currentIndex]
      : null;
  LyricDocument get lyrics => _lyrics[track?.uri] ?? const LyricDocument([]);
  double get position =>
      (_position +
              (playing
                  ? (clock.elapsedMicroseconds / 1e6 - _anchor) * rate
                  : 0))
          .clamp(0.0, duration > 0 ? duration : double.infinity);

  Future<void> _correlateClock() async {
    try {
      var best = double.infinity;
      for (var i = 0; i < 3; i++) {
        final before = clock.elapsedMicroseconds / 1000;
        final native = (await AndroidHost.methods.invokeMethod<num>(
          'getClock',
        ))!.toDouble();
        final after = clock.elapsedMicroseconds / 1000;
        if (after - before < best) {
          best = after - before;
          _nativeOffsetMs = native - (before + after) / 2;
        }
      }
      if (_lastNativeSampleMs != null) {
        _anchor = (_lastNativeSampleMs! - _nativeOffsetMs!) / 1000;
      }
    } catch (_) {
      /* Receipt-time interpolation remains available if native clock correlation fails. */
    }
  }

  Future<void> _restore() async {
    try {
      final values =
          await AndroidHost.methods.invokeListMethod<dynamic>('loadLibrary') ??
          [];
      if (_closed) return;
      final seen = tracks.map((track) => track.uri).toSet();
      tracks = [
        ...tracks,
        ...values
            .map((e) => AudioTrack.fromMap(Map<String, dynamic>.from(e as Map)))
            .where((track) => seen.add(track.uri)),
      ];
      if (_lastNativeUri != null) {
        currentIndex = tracks.indexWhere((t) => t.uri == _lastNativeUri);
      }
      await _syncQueue();
      _notify();
    } catch (failure) {
      error = failure.toString();
      _notify();
    }
  }

  List<Map<String, dynamic>> _catalog() => tracks
      .map(
        (t) => {
          'uri': t.uri,
          'title': t.title,
          'artist': t.artist,
          'coverPath': t.coverPath,
        },
      )
      .toList();
  Future<void> _syncQueue() =>
      AndroidHost.command('setQueue', {'items': _catalog()});
  void connect() {
    unawaited(_correlateClock());
    unawaited(_restore());
    _subscription = AndroidHost.events.receiveBroadcastStream().listen(
      (dynamic value) {
        final data = Map<String, dynamic>.from(value as Map);
        _lastNativeUri = data['uri'] as String?;
        if (_requestedUri != null && _requestedUri != _lastNativeUri) return;
        _requestedUri = null;
        _position = (data['positionMs'] as num).toDouble() / 1000;
        _lastNativeSampleMs = (data['sampledAtMs'] as num?)?.toDouble();
        _anchor = _lastNativeSampleMs != null && _nativeOffsetMs != null
            ? (_lastNativeSampleMs! - _nativeOffsetMs!) / 1000
            : clock.elapsedMicroseconds / 1e6;
        duration = (data['durationMs'] as num).toDouble() / 1000;
        playing = data['playing'] == true;
        rate = (data['speed'] as num?)?.toDouble() ?? 1;
        error = data['error'] as String?;
        final index = tracks.indexWhere((item) => item.uri == data['uri']);
        if (index >= 0) currentIndex = index;
        if (data['reason'] != 'clock') _notify();
      },
      onError: (Object failure) {
        error = failure.toString();
        _notify();
      },
    );
  }

  Future<void> importAudio() async {
    final imported = await AndroidHost.pickAudio();
    if (_closed) return;
    final known = tracks.map((t) => t.uri).toSet();
    tracks = [
      ...tracks,
      ...imported
          .where((d) => known.add(d['uri'] as String))
          .map(AudioTrack.fromMap),
    ];
    await _syncQueue();
    await AndroidHost.methods.invokeMethod<void>('saveLibrary', _catalog());
    _notify();
  }

  Future<void> select(int index) async {
    if (index < 0 || index >= tracks.length) return;
    currentIndex = index;
    _requestedUri = tracks[index].uri;
    _notify();
    await AndroidHost.command('play', {
      'uri': tracks[index].uri,
      'title': tracks[index].title,
      'artist': tracks[index].artist,
    });
  }

  Future<void> toggle() => AndroidHost.command(playing ? 'pause' : 'resume');
  Future<void> seek(double seconds) =>
      AndroidHost.command('seek', {'positionMs': (seconds * 1000).round()});
  Future<void> skip(int delta) => select(currentIndex + delta);
  Future<void> importLyrics() async {
    final uri = track?.uri;
    if (uri == null) return;
    final imported = await AndroidHost.pickLyrics();
    if (imported == null) return;
    _lyrics[uri] = LyricDocument.parse(
      imported['text'] as String,
      duration: duration,
    );
    _notify();
  }

  @override
  void dispose() {
    _closed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
