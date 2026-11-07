import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../artwork/cover_url.dart';
import '../../../../artwork/wall_image_pixels.dart';
import '../../../wall/wall_types.dart';
import '../../bravais_album_art.dart';
import 'bravais_artist_tone.dart';

part 'bravais_sample_watch.dart';

// Original URL-scoped sample caches and three-worker artist queue. Settle notifications touch only consumers of that URL; no polling or per-frame bridge exists.
class BravaisArtworkSamples {
  BravaisArtworkSamples({required this.urls, required this.sample});
  final CoverUrlPolicy urls;
  final Future<WallPixelSample> Function(String) sample;
  final _tones = <String, BravaisArtistTone>{},
      _spots = <String, List<WallPoint>>{};
  final _artistListeners = <String, Set<VoidCallback>>{},
      _spotListeners = <String, Set<VoidCallback>>{};
  final _artistPending = <String>{},
      _spotPending = <String>{},
      _artistQueue = Queue<String>();
  int _active = 0;
  bool _closed = false;
  ValueListenable<BravaisArtistTone?> artist(String url) =>
      _SampleWatch(() => _tones[url], _artistListeners, url);
  ValueListenable<List<WallPoint>?> spots(String url) =>
      _SampleWatch(() => _spots[url], _spotListeners, url);
  void requestArtist(String url) {
    if (_closed ||
        url.isEmpty ||
        _tones.containsKey(url) ||
        !_artistPending.add(url)) {
      return;
    }
    _artistQueue.addLast(url);
    _pump();
  }

  void _pump() {
    while (!_closed && _active < 3 && _artistQueue.isNotEmpty) {
      final url = _artistQueue.removeFirst();
      _active++;
      _artist(url).then((tone) {
        _active--;
        _artistPending.remove(url);
        if (!_closed) {
          _tones.remove(url);
          _tones[url] = tone;
          while (_tones.length > 800) {
            _tones.remove(_tones.keys.first);
          }
          _notify(_artistListeners[url]);
        }
        _pump();
      });
    }
  }

  Future<BravaisArtistTone> _artist(String url) async {
    try {
      final sized = urls.sized(url, 256);
      final pixels = await sample(sized.isEmpty ? url : sized);
      return switch (pixels.status) {
        WallPixelStatus.unavailable => BravaisArtistTone.unavailable,
        WallPixelStatus.unreadable => BravaisArtistTone.fallback,
        WallPixelStatus.ready => resolveBravaisArtistTone(pixels.pixels!),
      };
    } catch (_) {
      return BravaisArtistTone.fallback;
    }
  }

  void requestSpots(String url) {
    if (_closed ||
        urls.identity(url).isEmpty ||
        _spots.containsKey(url) ||
        !_spotPending.add(url)) {
      return;
    }
    _readSpots(url).then((spots) {
      _spotPending.remove(url);
      if (_closed) return;
      _spots[url] = spots;
      while (_spots.length > 400) {
        _spots.remove(_spots.keys.first);
      }
      _notify(_spotListeners[url]);
    });
  }

  Future<List<WallPoint>> _readSpots(String url) async {
    try {
      final sized = urls.sized(url, 128);
      final pixels = await sample(sized.isEmpty ? url : sized);
      return pixels.status == WallPixelStatus.ready
          ? findBravaisCoverSpots(
              pixels.pixels!,
              math.sqrt(pixels.pixels!.length / 4).round(),
            )
          : bravaisFallbackCoverSpots;
    } catch (_) {
      return bravaisFallbackCoverSpots;
    }
  }

  void _notify(Set<VoidCallback>? callbacks) {
    for (final callback
        in callbacks?.toList(growable: false) ?? const <VoidCallback>[]) {
      callback();
    }
  }

  void dispose() {
    _closed = true;
    _artistQueue.clear();
    _artistPending.clear();
    _spotPending.clear();
    _tones.clear();
    _spots.clear();
    _artistListeners.clear();
    _spotListeners.clear();
  }
}
