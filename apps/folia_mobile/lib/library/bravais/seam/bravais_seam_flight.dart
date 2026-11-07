import '../../../visualizer/motion/bezier.dart';

// Seam flips have their own 160/240ms ease-in/Bezier vocabulary; reusing the wall tile's 150ms outgoing curve changes the original animation.
enum BravaisSeamFlipAxis { x, y }

enum BravaisSeamFlipPhase { flipOut, flipIn, fadeOut, fadeIn }

class BravaisSeamFlightSample {
  const BravaisSeamFlightSample({
    this.degrees = 0,
    this.opacity = 1,
    this.transformEffect = false,
    this.opacityEffect = false,
  });
  final double degrees, opacity;
  final bool transformEffect, opacityEffect;
}

class BravaisSeamFlight {
  const BravaisSeamFlight(this.phase, this.start);
  final BravaisSeamFlipPhase phase;
  final double start;
  bool get outgoing =>
      phase == BravaisSeamFlipPhase.flipOut ||
      phase == BravaisSeamFlipPhase.fadeOut;
  double get duration => switch (phase) {
    BravaisSeamFlipPhase.flipOut => 160,
    BravaisSeamFlipPhase.flipIn => 240,
    _ => 90,
  };
  bool done(double now) => now >= start + duration;
  BravaisSeamFlightSample sample(double now) {
    final p = ((now - start) / duration).clamp(0.0, 1.0),
        ease = switch (phase) {
          BravaisSeamFlipPhase.flipOut ||
          BravaisSeamFlipPhase.fadeOut => cssBezier(.42, 0, 1, 1, p),
          BravaisSeamFlipPhase.flipIn => cssBezier(.2, .7, .25, 1, p),
          BravaisSeamFlipPhase.fadeIn => cssBezier(0, 0, .58, 1, p),
        };
    return switch (phase) {
      BravaisSeamFlipPhase.flipOut => BravaisSeamFlightSample(
        degrees: 90 * ease,
        transformEffect: true,
      ),
      BravaisSeamFlipPhase.flipIn => BravaisSeamFlightSample(
        degrees: -90 * (1 - ease),
        transformEffect: true,
      ),
      BravaisSeamFlipPhase.fadeOut => BravaisSeamFlightSample(
        opacity: 1 - ease,
        opacityEffect: true,
      ),
      BravaisSeamFlipPhase.fadeIn => BravaisSeamFlightSample(
        opacity: ease,
        opacityEffect: true,
      ),
    };
  }
}
