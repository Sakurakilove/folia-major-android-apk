import 'dart:math' as math;

// Exact port of utils/lyrics/renderHints.ts; source end times and render end times are distinct.
class LineRenderHints {
  const LineRenderHints({
    required this.rawDuration,
    required this.timingClass,
    required this.renderEndTime,
    required this.lineTransitionMode,
    required this.wordRevealMode,
  });
  final double rawDuration, renderEndTime;
  final String timingClass, lineTransitionMode, wordRevealMode;

  factory LineRenderHints.fromJson(Map<String, dynamic> data) =>
      LineRenderHints(
        rawDuration: (data['rawDuration'] as num).toDouble(),
        renderEndTime: (data['renderEndTime'] as num).toDouble(),
        timingClass: data['timingClass'] as String,
        lineTransitionMode: data['lineTransitionMode'] as String,
        wordRevealMode: data['wordRevealMode'] as String,
      );

  Map<String, dynamic> toJson() => {
    'rawDuration': rawDuration,
    'timingClass': timingClass,
    'renderEndTime': renderEndTime,
    'lineTransitionMode': lineTransitionMode,
    'wordRevealMode': wordRevealMode,
  };
}

({double enterDuration, double exitDuration, double linePassHold})
getLineTransitionTiming(double rawDuration, String mode, String reveal) {
  if (mode == 'none') {
    return (enterDuration: 0, exitDuration: 0, linePassHold: 0);
  }
  if (mode == 'fast') {
    return (
      enterDuration: (rawDuration * .45).clamp(.045, .06),
      exitDuration: (rawDuration * .22).clamp(.03, .04),
      linePassHold: reveal == 'instant' ? 0 : .03,
    );
  }
  return (
    enterDuration: (math.max(rawDuration, .12) * .34).clamp(.22, .42),
    exitDuration: (math.max(rawDuration, .12) * .18).clamp(.18, .32),
    linePassHold: reveal == 'instant' ? 0 : .06,
  );
}

LineRenderHints buildLineRenderHints(
  double start,
  double end, {
  double? lastWordEnd,
}) {
  final duration = math.max(end - start, 0.0);
  final timingClass = duration < .10
      ? 'micro'
      : duration < .18
      ? 'short'
      : 'normal';
  final mode = timingClass == 'micro'
      ? 'none'
      : timingClass == 'short'
      ? 'fast'
      : 'normal';
  final reveal = timingClass == 'micro'
      ? 'instant'
      : timingClass == 'short'
      ? 'fast'
      : 'normal';
  double renderEnd;
  if (mode == 'none') {
    renderEnd = math.max(end, start + .067);
  } else {
    final transition = getLineTransitionTiming(duration, mode, reveal);
    final passStart =
        math.max(lastWordEnd ?? end, start) + transition.linePassHold;
    final exitStart = mode == 'fast'
        ? math.max(
            math.max(start + transition.enterDuration + .01, passStart),
            end - transition.exitDuration,
          )
        : math.max(passStart, end - transition.exitDuration);
    renderEnd = math.max(end, exitStart + transition.exitDuration);
  }
  return LineRenderHints(
    rawDuration: duration,
    timingClass: timingClass,
    renderEndTime: renderEnd,
    lineTransitionMode: mode,
    wordRevealMode: reveal,
  );
}
