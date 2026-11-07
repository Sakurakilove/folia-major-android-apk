import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../../visualizer/motion/css_transition.dart';
import '../../bravais_album_art.dart';
import '../bravais_item.dart';
import 'bravais_art_style.dart';

// Original shard filter/overlays use 260ms CSS ease even when lattice motion is reduced. Mode switches create/remove pseudo-elements independently of the existing image's filter.
class BravaisAlbumArtMotion extends ChangeNotifier
    implements ValueListenable<BravaisArtStyle> {
  BravaisAlbumArtMotion({
    required this._frames,
    required this.nowMs,
    required BravaisArtMode mode,
    required this._placement,
    required this._accent,
    required this._block,
    required bool restored,
  }) : _mode = mode,
       _restored = restored,
       _filter = CssNumericTransition(
         mode == BravaisArtMode.shard && !restored ? 1 : 0,
       ),
       _overlay = CssNumericTransition(
         mode == BravaisArtMode.shard && !restored ? 1 : 0,
       ) {
    _snapshot();
  }
  Listenable _frames;
  double Function() nowMs;
  BravaisArtMode _mode;
  BravaisArtPlacement _placement;
  Color _accent, _block;
  bool _restored, _attached = false, _closed = false;
  final CssNumericTransition _filter, _overlay;
  late BravaisArtStyle _value;
  @override
  BravaisArtStyle get value => _value;
  void rebind(Listenable frames, double Function() clock) {
    nowMs = clock;
    if (identical(frames, _frames)) return;
    if (_attached) _frames.removeListener(_frame);
    _attached = false;
    _frames = frames;
    _sync();
  }

  void update({
    required BravaisArtMode mode,
    required BravaisArtPlacement placement,
    required Color accent,
    required Color block,
    required bool restored,
  }) {
    if (_closed) return;
    final modeChanged = mode != _mode,
        now = nowMs(),
        target = mode == BravaisArtMode.shard && !restored ? 1.0 : 0.0;
    _mode = mode;
    _placement = placement;
    _accent = accent;
    _block = block;
    _restored = restored;
    _filter.setTarget(target, now, const CssTransitionSpec(260));
    if (modeChanged) {
      _overlay.jump(target);
    } else {
      _overlay.setTarget(target, now, const CssTransitionSpec(260));
    }
    _snapshot();
    _sync();
    notifyListeners();
  }

  void _snapshot() {
    final shard = _mode == BravaisArtMode.shard, p = _filter.value;
    _value = BravaisArtStyle(
      mode: shard ? BravaisArtShaderMode.shard : BravaisArtShaderMode.mosaic,
      placement: _placement,
      light: shard ? _accent : const Color(0x00000000),
      dark: shard ? _block : const Color(0x00000000),
      grayscale: p,
      contrast: 1 + 1.2 * p,
      brightness: 1 + .3 * p,
      multiply: shard && !_restored,
      darkOpacity: shard ? _overlay.value : 0,
      dotOpacity: shard ? _overlay.value : 0,
    );
  }

  void _advance() {
    final now = nowMs();
    _filter.advance(now);
    _overlay.advance(now);
    _snapshot();
  }

  void _sync() {
    final wanted =
        !_closed &&
        hasListeners &&
        (_filter.isAnimating || _overlay.isAnimating);
    if (wanted == _attached) return;
    _attached = wanted;
    if (wanted) {
      _frames.addListener(_frame);
    } else {
      _frames.removeListener(_frame);
    }
  }

  void _frame() {
    if (_closed) return;
    _advance();
    _sync();
    notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _advance();
    _sync();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _sync();
  }

  @override
  void dispose() {
    _closed = true;
    _sync();
    super.dispose();
  }
}
