import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/classic/classic_layout.dart';
import 'package:folia_mobile/lyrics/lyric_types.dart';
import 'package:folia_mobile/visualizer/glow_word/glow_line_motion.dart';
import 'package:folia_mobile/visualizer/glow_word/glow_line_playback.dart';
import 'package:folia_mobile/visualizer/glow_word/glow_word_motion.dart';
import 'package:folia_mobile/visualizer/glow_word/glow_word_timing.dart';
import 'package:folia_mobile/visualizer/motion/color_value.dart';

// A focused power/lifetime contract: paused finite effects settle, hidden lines detach, and discrete seeks reattach without a per-word ticker.
class _Signal extends ChangeNotifier {
  bool get listening => hasListeners;
  void tick() => notifyListeners();
}

void main() {
  test('settled and hidden lines release shared vsync and audio listeners', () {
    final frames = _Signal(), audio = _Signal();
    var now = 0.0, position = 0.0, retired = 0;
    const w = LyricWord('abc', 2, 2.4);
    final profile = GlowWordRenderProfile(const LyricLine('abc', 2, 4, [w]));
    final word = GlowWordMotion(
      word: w,
      profile: profile,
      config: const ClassicWordConfig(
        id: 'w',
        x: 3,
        y: 5,
        rotate: 7,
        scale: 1,
        passedRotate: 4,
        marginRight: '0px',
        alignSelf: 'auto',
      ),
      intensity: 'normal',
      baseColor: const MotionRgba(20, 30, 40),
      activeColor: const MotionRgba(200, 150, 80),
      rippleScale: 2,
      chorus: true,
    );
    final runtime = GlowLinePlayback(
      words: [word],
      line: GlowLineMotion(profile, now),
      frames: frames,
      audioChanges: audio,
      audioTime: () => position,
      milliseconds: () => now,
      isPlaying: () => false,
      isGlowBlurQuantized: () => false,
      onRetired: () => retired++,
    );
    expect(frames.listening, true);
    now = 2000;
    frames.tick();
    expect(frames.listening, false);
    position = 2.05;
    audio.tick();
    expect(word.status, 'active');
    expect(frames.listening, true);
    now = 4000;
    frames.tick();
    expect(frames.listening, false);
    position = 2.5;
    audio.tick();
    expect(word.status, 'passed');
    expect(frames.listening, true);
    now = 6000;
    frames.tick();
    expect(
      frames.listening,
      true,
    ); // Original passed rotation lasts five seconds.
    now = 10000;
    frames.tick();
    expect(frames.listening, false);
    runtime.setActive(false);
    position = 1;
    audio.tick();
    expect(word.status, 'passed');
    expect(frames.listening, false);
    runtime.setActive(true);
    expect(word.status, 'waiting');
    expect(frames.listening, true);
    runtime.leave(textHidden: true);
    now += 201;
    frames.tick();
    expect(retired, 1);
    expect(frames.listening, false);
    runtime.dispose();
    expect(audio.listening, false);
    frames.dispose();
    audio.dispose();
  });
}
