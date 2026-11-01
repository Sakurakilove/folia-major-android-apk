import 'lyric_types.dart';

// Shared visualizer/runtime.ts selection/preheat contracts, independent of Flutter frames or platform channels.
LyricLine? getRecentCompletedLine({
  required List<LyricLine> lines,
  required int currentLineIndex,
  required double currentTime,
  double Function(LyricLine)? getLineEndTime,
}) {
  if (currentLineIndex != -1 || lines.isEmpty) return null;
  for (var i = lines.length - 1; i >= 0; i--) {
    if (currentTime > (getLineEndTime?.call(lines[i]) ?? lines[i].end)) {
      return lines[i];
    }
  }
  return null;
}

LyricLine? getUpcomingLine(
  List<LyricLine> lines,
  int currentLineIndex,
  double currentTime,
) {
  if (currentLineIndex >= 0 && currentLineIndex < lines.length) {
    return currentLineIndex + 1 < lines.length
        ? lines[currentLineIndex + 1]
        : null;
  }
  for (final line in lines) {
    if (line.start > currentTime) return line;
  }
  return null;
}

List<LyricLine> getUpcomingLines(
  List<LyricLine> lines,
  int currentLineIndex, [
  int count = 2,
]) {
  if (currentLineIndex < 0) return const [];
  final start = (currentLineIndex + 1).clamp(0, lines.length);
  final end = (currentLineIndex + 1 + count).clamp(0, lines.length);
  return end < start ? const [] : lines.sublist(start, end);
}

bool shouldPreheatLine(
  LyricLine? line,
  double time, {
  required double minLead,
  required double maxLead,
}) {
  if (line == null) return false;
  final lead = line.start - time;
  return lead >= minLead && lead <= maxLead;
}

T? prepareActiveAndUpcoming<T>({
  required LyricLine? activeLine,
  required LyricLine? upcomingLine,
  required T? Function(LyricLine?) prepareLine,
}) {
  if (activeLine == null) {
    prepareLine(upcomingLine);
    return null;
  }
  final current = prepareLine(activeLine);
  prepareLine(upcomingLine);
  return current;
}
