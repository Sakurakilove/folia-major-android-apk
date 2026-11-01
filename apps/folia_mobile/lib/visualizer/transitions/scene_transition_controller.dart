import 'dart:async';

import 'package:flutter/foundation.dart';

import 'scene_layers.dart';

// Discrete transition ownership for every lyric style/background; no periodic timer or frame bridge.
class SceneTransitionController<T> extends ChangeNotifier {
  SceneTransitionController(
    T initial, {
    this.firstFrameLimit = const Duration(milliseconds: 1500),
  }) : _requested = initial,
       _layers = [
         SceneLayer(
           key: 0,
           value: initial,
           leaving: false,
           comesIn: false,
           waits: false,
         ),
       ];
  final Duration firstFrameLimit;
  List<SceneLayer<T>> _layers;
  List<SceneLayer<T>> get layers => List.unmodifiable(_layers);
  T _requested;
  bool _animate = false, _waits = false, _closed = false;
  Timer? _limit;
  int? _waitingKey;
  bool get waits => _layers.last.waits;

  void request(T value, {required bool animate, required bool waits}) {
    if (_closed) return;
    _requested = value;
    _animate = animate;
    _waits = waits;
    _apply(nextShownLayers(_layers, value, animate, waits));
  }

  void firstFrame(int key) {
    if (_closed) return;
    _apply(startedLayers(_layers, key));
  }

  void left(int key) {
    if (_closed || !_layers.any((layer) => layer.key == key && layer.leaving)) {
      return;
    }
    final remaining = _layers.where((layer) => layer.key != key).toList();
    _apply(nextShownLayers(remaining, _requested, _animate, _waits));
  }

  void _apply(List<SceneLayer<T>> next) {
    if (identical(next, _layers)) return;
    _layers = next;
    final waitingKey = _layers.last.waits ? _layers.last.key : null;
    if (_waitingKey != waitingKey) {
      _waitingKey = waitingKey;
      _limit?.cancel();
      _limit = null;
      if (waitingKey != null) {
        _limit = Timer(firstFrameLimit, () => firstFrame(waitingKey));
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _limit?.cancel();
    super.dispose();
  }
}
