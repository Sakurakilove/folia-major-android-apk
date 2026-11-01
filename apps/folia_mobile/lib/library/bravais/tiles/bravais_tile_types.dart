import '../../wall/wall_types.dart';

// Face keys include content/window/transparency identity; the payload keeps the complete original card projection.
class BravaisTileFace<T> {
  const BravaisTileFace(this.key, this.payload);
  final String? key;
  final T payload;
}

class BravaisFlipStep {
  const BravaisFlipStep(
    this.token,
    this.to,
    this.delay,
    this.direction, {
    this.waveInDelay,
  });
  final int token, direction;
  final String? to;
  final double delay;
  final double? waveInDelay;
}

class BravaisEntrance {
  const BravaisEntrance({
    required this.token,
    required this.corner,
    required this.startedAt,
    required this.until,
    required this.reduced,
    this.mountsOnly = false,
  });
  final int token;
  final WallPoint corner;
  final double startedAt, until;
  final bool reduced, mountsOnly;
}

enum BravaisTileTransition { none, flip, fade, swap }

BravaisTileTransition resolveBravaisTileTransition(
  String? shown,
  String? target,
  BravaisFlipStep? step,
  bool reducedMotion,
) => shown == target
    ? BravaisTileTransition.none
    : step != null && step.to == target
    ? reducedMotion
          ? BravaisTileTransition.fade
          : BravaisTileTransition.flip
    : BravaisTileTransition.swap;
