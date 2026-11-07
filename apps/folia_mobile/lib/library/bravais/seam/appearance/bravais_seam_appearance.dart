import 'package:flutter/foundation.dart';

import '../../../../rendering/gradients/css_gradient_program.dart';
import '../../../../visualizer/motion/css_transition.dart';
import 'bravais_seam_look.dart';
import 'bravais_seam_tint_painter.dart';

// Appearance owns only finite CSS transitions and live shader leases. The stage supplies discrete source state; no channel or widget is updated for an opacity frame.
class BravaisSeamAppearance extends ChangeNotifier {
  BravaisSeamAppearance({
    required BravaisSeamLook look,
    required Listenable frames,
    required double Function() nowMs,
    required CssGradientProgram gradients,
    this.reducedMotion = false,
  }) : _look = look,
       paperTint = CssNumericSignal(
         look.paperTint,
         frames: frames,
         nowMs: nowMs,
       ),
       textTint = CssNumericSignal(look.textTint, frames: frames, nowMs: nowMs),
       bodyOpacity = CssNumericSignal(
         look.bodyOpacity,
         frames: frames,
         nowMs: nowMs,
       ) {
    underlay = BravaisSeamTintPainter(this, gradients, foreground: false);
    overlay = BravaisSeamTintPainter(this, gradients, foreground: true);
  }
  BravaisSeamLook _look;
  BravaisSeamLook get look => _look;
  final CssNumericSignal paperTint, textTint, bodyOpacity;
  late final BravaisSeamTintPainter underlay, overlay;
  bool reducedMotion, _closed = false;
  Iterable<CssNumericSignal> get _signals => [paperTint, textTint, bodyOpacity];
  void update(BravaisSeamLook next, {required bool reducedMotion}) {
    if (_closed) return;
    _look = next;
    this.reducedMotion = reducedMotion;
    const transition = CssTransitionSpec(260);
    paperTint.setTarget(next.paperTint, transition, enabled: !reducedMotion);
    textTint.setTarget(next.textTint, transition, enabled: !reducedMotion);
    bodyOpacity.setTarget(
      next.bodyOpacity,
      transition,
      enabled: !reducedMotion,
    );
    // Background/color changes are immediate in the original; only opacity has a transition.
    notifyListeners();
  }

  void rebind(Listenable frames, double Function() nowMs) {
    if (_closed) return;
    for (final signal in _signals) {
      signal.nowMs = nowMs;
      signal.rebindFrames(frames);
    }
  }

  void setActive(bool value) {
    if (_closed) return;
    for (final signal in _signals) {
      signal.setActive(value);
    }
  }

  @override
  void dispose() {
    _closed = true;
    underlay.dispose();
    overlay.dispose();
    for (final signal in _signals) {
      signal.dispose();
    }
    super.dispose();
  }
}
