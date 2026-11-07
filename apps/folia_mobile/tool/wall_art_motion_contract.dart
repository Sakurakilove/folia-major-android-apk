import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/tiles/artwork/bravais_artist_art_motion.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_card_palette.dart';
import 'package:folia_mobile/library/wall/wall_css_paint.dart';

// This is part of the single focused art check: invisible color tracks retain absolute time but do not keep the display clock awake.
void checkWallArtMotion() {
  final frames = _ArtFrames();
  var now = 0.0;
  const palette = BravaisCardPalette(
    background: Color(0xff070707),
    ink: Color(0xfff7f4ee),
    accent: Color(0xfffd5c47),
    secondary: Color(0xff6a48ff),
    daylight: false,
  );
  final target = wallCssHsl(213, .62, .66),
      fallback = wallFallbackColors('artist');
  final motion = BravaisArtistArtMotion(
    frames: frames,
    nowMs: () => now,
    palette: palette,
    light: palette.accent,
    restored: false,
    fallback: false,
    fallbackColors: fallback,
    reducedMotion: false,
  );
  void listener() {}
  motion.addListener(listener);
  expect(frames.count, 0);
  motion.update(
    palette: palette,
    light: target,
    restored: true,
    fallback: false,
    fallbackColors: fallback,
    reducedMotion: false,
  );
  expect(frames.count, 1);
  now = 300;
  frames.tick();
  expect(motion.value.opacity, 0);
  expect(frames.count, 0);
  now = 500;
  motion.update(
    palette: palette,
    light: target,
    restored: false,
    fallback: false,
    fallbackColors: fallback,
    reducedMotion: false,
  );
  expect(motion.value.light.r, closeTo(target.r, 1e-8));
  expect(motion.value.opacity, 0);
  expect(frames.count, 1);
  now = 800;
  frames.tick();
  expect(motion.value.opacity, 1);
  expect(frames.count, 0);
  motion.dispose();
  frames.dispose();
}

class _ArtFrames extends ChangeNotifier {
  int count = 0;
  @override
  void addListener(VoidCallback listener) {
    count++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    count--;
    super.removeListener(listener);
  }

  void tick() => notifyListeners();
}
