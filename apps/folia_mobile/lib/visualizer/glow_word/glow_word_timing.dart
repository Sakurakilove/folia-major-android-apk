import 'dart:math' as math;

import '../../lyrics/lyric_types.dart';
import '../../lyrics/render_hints.dart';

// Classic and Partita share the original render-hint profile, lookahead and per-word duration rules.
class GlowWordRenderProfile {
  factory GlowWordRenderProfile(LyricLine line) =>
      GlowWordRenderProfile._(line.hints);
  GlowWordRenderProfile._(this.renderHints)
    : lineRenderEndTime = renderHints.renderEndTime,
      lineTransitionMode = renderHints.lineTransitionMode,
      wordRevealMode = renderHints.wordRevealMode;
  final LineRenderHints renderHints;
  final double lineRenderEndTime;
  final String lineTransitionMode, wordRevealMode;
  double get wordLookahead => wordRevealMode == 'instant'
      ? .03
      : wordRevealMode == 'fast'
      ? .08
      : .15;
  double activeEnd(LyricWord word) => wordRevealMode == 'instant'
      ? lineRenderEndTime
      : wordRevealMode == 'fast'
      ? math.min(lineRenderEndTime, math.max(word.end, word.start + .12))
      : word.end;
  double displayDuration(LyricWord word) => math.max(
    activeEnd(word) - word.start,
    wordRevealMode == 'instant'
        ? .08
        : wordRevealMode == 'fast'
        ? .12
        : .1,
  );
  String status(LyricWord word, double time) =>
      time >= word.start - wordLookahead && time <= activeEnd(word)
      ? 'active'
      : time > activeEnd(word)
      ? 'passed'
      : 'waiting';
  Map<String, dynamic> toJson() => {
    'renderHints': renderHints.toJson(),
    'lineRenderEndTime': lineRenderEndTime,
    'lineTransitionMode': lineTransitionMode,
    'wordRevealMode': wordRevealMode,
    'wordLookahead': wordLookahead,
  };
}

// Omitted transition fields remain omitted: the shared Framer-compatible motion adapter must resolve original defaults.
Map<String, dynamic> glowWordLineContainerMotion(
  GlowWordRenderProfile? profile,
) {
  final mode = profile?.lineTransitionMode;
  if (mode == 'none') {
    return {
      'initial': {'opacity': 1, 'scale': 1, 'filter': 'blur(0px)'},
      'animate': {
        'opacity': 1,
        'scale': 1,
        'filter': 'blur(0px)',
        'transitionEnd': {'filter': 'none'},
      },
      'exit': {
        'opacity': 0,
        'scale': 1.02,
        'filter': 'blur(6px)',
        'transition': {'duration': .12, 'ease': 'easeOut'},
      },
    };
  }
  if (mode == 'fast') {
    return {
      'initial': {'opacity': .35, 'scale': .96, 'filter': 'blur(4px)'},
      'animate': {
        'opacity': 1,
        'scale': 1,
        'filter': 'blur(0px)',
        'transition': {'duration': .16, 'ease': 'easeOut'},
        'transitionEnd': {'filter': 'none'},
      },
      'exit': {
        'opacity': 0,
        'scale': 1.04,
        'filter': 'blur(10px)',
        'transition': {'duration': .16, 'ease': 'easeInOut'},
      },
    };
  }
  return {
    'initial': {'opacity': 0, 'scale': .9, 'filter': 'blur(10px)'},
    'animate': {
      'opacity': 1,
      'scale': 1,
      'filter': 'blur(0px)',
      'transitionEnd': {'filter': 'none'},
    },
    'exit': {
      'opacity': 0,
      'scale': 1.1,
      'filter': 'blur(20px)',
      'transition': {'duration': .3},
    },
  };
}
