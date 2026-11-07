import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../rendering/js_text.dart';
import 'bravais_album_motion.dart';

part 'bravais_album_signal.dart';

// One finite clock serves the mounted original album poster. Discrete CSS animation-name changes restart only the affected tracks; title updates retain index-keyed word animations.
class BravaisAlbumEntrance extends ChangeNotifier {
  BravaisAlbumEntrance({
    required this.frames,
    required this.nowMs,
    required List<String> words,
    bool reducedMotion = false,
    this._active = true,
    this._cover = BravaisAlbumCoverState.ordinary,
  }) : _reduced = reducedMotion {
    _now = _epoch = _coverEpoch = nowMs();
    _words = [
      for (final word in words) (space: jsTrim(word).isEmpty, at: _now),
    ];
  }
  Listenable frames;
  double Function() nowMs;
  late double _now, _epoch, _coverEpoch;
  late List<({bool space, double at})> _words;
  bool _reduced, _active, _attached = false, _closed = false;
  BravaisAlbumCoverState _cover;
  int _version = 0;
  final _signals = <(BravaisAlbumPart, int), _AlbumMotionSignal>{};
  final _samples =
      <
        (BravaisAlbumPart, int),
        ({double at, int version, BravaisAlbumMotion frame})
      >{};
  ValueListenable<BravaisAlbumMotion> signal(
    BravaisAlbumPart part, [
    int index = 0,
  ]) => _signals.putIfAbsent((
    part,
    index,
  ), () => _AlbumMotionSignal(this, part, index));
  BravaisAlbumMotion sample(BravaisAlbumPart part, [int index = 0]) {
    final key = (part, index), cached = _samples[key];
    if (cached != null && cached.version == _version && cached.at == _now) {
      return cached.frame;
    }
    final word =
            part == BravaisAlbumPart.word && index >= 0 && index < _words.length
            ? _words[index]
            : null,
        at = part == BravaisAlbumPart.cover ? _coverEpoch : word?.at ?? _epoch,
        frame = sampleBravaisAlbumMotion(
          part: part,
          elapsed: _now - at,
          reducedMotion: _reduced,
          cover: _cover,
          index: index,
          space: word?.space ?? false,
        );
    _samples[key] = (at: _now, version: _version, frame: frame);
    return frame;
  }

  void updateWords(List<String> words) {
    if (_closed) return;
    _now = nowMs();
    final next = <({bool space, double at})>[];
    for (var i = 0; i < words.length; i++) {
      final space = jsTrim(words[i]).isEmpty,
          old = i < _words.length ? _words[i] : null;
      next.add((
        space: space,
        at: old != null && old.space == space ? old.at : _now,
      ));
    }
    _words = next;
    _changed();
  }

  void setCover(BravaisAlbumCoverState value) {
    if (_closed || value == _cover) return;
    _now = nowMs();
    _cover = value;
    if (value == BravaisAlbumCoverState.ordinary) _coverEpoch = _now;
    _changed();
  }

  void setReducedMotion(bool value) {
    if (_closed || value == _reduced) return;
    _now = nowMs();
    _reduced = value;
    _epoch = _coverEpoch = _now;
    _words = [for (final w in _words) (space: w.space, at: _now)];
    _changed();
  }

  void setActive(bool value) {
    if (_closed || value == _active) return;
    _active = value;
    if (value) {
      _now = nowMs();
      notifyListeners();
    }
    _sync();
  }

  void rebind(Listenable value, double Function() clock) {
    if (_closed) return;
    nowMs = clock;
    if (identical(value, frames)) return;
    if (_attached) frames.removeListener(_frame);
    _attached = false;
    frames = value;
    _sync();
  }

  void _changed() {
    _version++;
    _samples.clear();
    notifyListeners();
    _sync();
  }

  double get _end {
    if (_reduced) return _epoch + 180;
    var end = math.max(
      _epoch + 1200,
      _cover == BravaisAlbumCoverState.ordinary ? _coverEpoch + 680 : _epoch,
    );
    for (var i = 0; i < _words.length; i++) {
      if (!_words[i].space) {
        end = math.max(end, _words[i].at + 300 + i * 70 + 520);
      }
    }
    return end;
  }

  void _frame() {
    if (_closed || !_active) return;
    _now = nowMs();
    notifyListeners();
    _sync();
  }

  void _sync() {
    final wanted = !_closed && _active && hasListeners && _now < _end;
    if (_attached == wanted) return;
    _attached = wanted;
    if (wanted) {
      frames.addListener(_frame);
    } else {
      frames.removeListener(_frame);
    }
  }

  @override
  void addListener(VoidCallback listener) {
    _now = nowMs();
    super.addListener(listener);
    _sync();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _sync();
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _sync();
    for (final signal in _signals.values) {
      signal.dispose();
    }
    _signals.clear();
    _samples.clear();
    super.dispose();
  }
}
