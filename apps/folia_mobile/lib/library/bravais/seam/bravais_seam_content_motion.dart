import 'package:flutter/foundation.dart';

import 'bravais_seam_flight.dart';
import 'bravais_seam_level.dart';

// Identity is the original layer key plus variant. Data refreshes preserve the visible variant and can update its content during the outgoing half.
class BravaisRenderedSeam<T> {
  const BravaisRenderedSeam(this.variant, this.layerKey, this.layer);
  final BravaisSeamVariant variant;
  final String? layerKey;
  final T? layer;
  String get key => '${variant.wireName}|${layerKey ?? ''}';
}

// Finite controller preserves the source effect-dependency identity, including A→B→C retargeting without restarting the outgoing half.
class BravaisSeamContentMotion<T> extends ChangeNotifier {
  BravaisSeamContentMotion({
    required this.frames,
    required this.nowMs,
    required BravaisRenderedSeam<T> initial,
    this.reducedTransitions = false,
    this.hasElement = true,
    this.beforeLeave,
    this.onCommit,
    this.onSettled,
  }) : _rendered = initial,
       _target = initial,
       content = ValueNotifier(initial) {
    _effect = (_mode, reducedTransitions, _rendered.key);
  }
  Listenable frames;
  double Function() nowMs;
  bool reducedTransitions, hasElement;
  final void Function()? beforeLeave, onSettled;
  final void Function(BravaisRenderedSeam<T>)? onCommit;
  final ValueNotifier<BravaisRenderedSeam<T>> content;
  final leavingValue = ValueNotifier(false);
  BravaisRenderedSeam<T> _rendered, _target;
  (String, bool, String)? _effect;
  BravaisSeamFlight? _flight;
  bool _active = true, _attached = false, _closed = false, _leaving = false;
  bool get leaving => _leaving;
  BravaisSeamFlipPhase? get phase => _flight?.phase;
  BravaisSeamFlightSample sample = const BravaisSeamFlightSample();
  String get _mode => _rendered.key == _target.key
      ? 'none'
      : (_rendered.variant == BravaisSeamVariant.none ||
            _target.variant == BravaisSeamVariant.none)
      ? 'swap|${_target.key}'
      : 'flip';
  void update(
    BravaisRenderedSeam<T> next, {
    required bool reducedTransitions,
    required bool hasElement,
  }) {
    if (_closed) return;
    _target = next;
    this.reducedTransitions = reducedTransitions;
    this.hasElement = hasElement;
    _applyEffect();
    _publishContent();
    _sample();
    _sync();
    notifyListeners();
  }

  void _applyEffect() {
    final mode = _mode, effect = (mode, reducedTransitions, _rendered.key);
    _leaving = mode == 'flip';
    if (effect == _effect) return;
    // Cleanup only cancels an unfinished outgoing effect; a completed incoming animation survives a swap-to-none just as WAAPI does.
    if (_flight?.outgoing ?? false) _flight = null;
    _effect = effect;
    if (mode == 'none') return;
    final fromNone = _rendered.variant == BravaisSeamVariant.none;
    beforeLeave?.call();
    if (!hasElement || mode != 'flip') {
      _commit(
        animateIn: hasElement && fromNone && reducedTransitions,
        fromNone: fromNone,
      );
    } else {
      _flight = BravaisSeamFlight(
        reducedTransitions
            ? BravaisSeamFlipPhase.fadeOut
            : BravaisSeamFlipPhase.flipOut,
        nowMs(),
      );
    }
  }

  void _commit({required bool animateIn, required bool fromNone}) {
    _rendered = _target;
    _publishContent();
    onCommit?.call(_rendered);
    if (animateIn && hasElement) {
      _flight = BravaisSeamFlight(
        reducedTransitions || fromNone
            ? BravaisSeamFlipPhase.fadeIn
            : BravaisSeamFlipPhase.flipIn,
        nowMs(),
      );
    }
    // The new rendered key changes the source layout effect dependency even when there is now no transition to schedule.
    _applyEffect();
  }

  void _publishContent() {
    final shown =
            _rendered.layerKey != null &&
                _target.layerKey != null &&
                _rendered.layerKey == _target.layerKey
            ? BravaisRenderedSeam(
                _rendered.variant,
                _rendered.layerKey,
                _target.layer,
              )
            : _rendered,
        old = content.value;
    if (shown.variant != old.variant ||
        shown.layerKey != old.layerKey ||
        !identical(shown.layer, old.layer)) {
      content.value = shown;
    }
  }

  void _sample() {
    sample = _flight?.sample(nowMs()) ?? const BravaisSeamFlightSample();
  }

  void _frame() {
    if (_closed || !_active) return;
    final flight = _flight;
    if (flight != null && flight.done(nowMs())) {
      if (flight.outgoing) {
        _flight = null;
        _commit(animateIn: true, fromNone: false);
      } else {
        _flight = null;
        onSettled?.call();
      }
    }
    _sample();
    _sync();
    notifyListeners();
  }

  void _sync() {
    leavingValue.value = leaving;
    final wanted = !_closed && _active && _flight != null;
    if (wanted == _attached) return;
    _attached = wanted;
    if (wanted) {
      frames.addListener(_frame);
    } else {
      frames.removeListener(_frame);
    }
  }

  void rebindFrames(Listenable next) {
    if (_closed || identical(next, frames)) return;
    if (_attached) frames.removeListener(_frame);
    _attached = false;
    frames = next;
    _sync();
  }

  void setActive(bool value) {
    if (_closed || _active == value) return;
    _active = value;
    if (value) _frame();
    _sync();
  }

  @override
  void dispose() {
    _closed = true;
    _sync();
    content.dispose();
    leavingValue.dispose();
    super.dispose();
  }
}
