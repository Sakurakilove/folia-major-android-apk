part of 'monet_rail.dart';

// Selection logic stays outside the rail widget assembly.
extension _MonetRailSelection on _MonetRailState {
  void _frame() {
    if (!mounted || _size.isEmpty) return;
    final now = widget.seconds(), time = widget.position();
    _sync();
    var changed = false;
    if (_hasExiting) {
      for (final key in _rows.keys.toList()) {
        if (_rows[key]!.motion.exited(now)) {
          _rows.remove(key)!.dispose();
          changed = true;
        }
      }
    }
    if (changed) {
      _order();
      _pinAndWarm();
    }
    final moving = _ordered.any(
      (row) =>
          row.motion.animating(now) ||
          row.motion.entry.layout.subtitleTracks.isNotEmpty &&
              now - row.motion.subtitleStart < .32,
    );
    if (changed || moving || time != _lastPaintPosition) {
      _lastPaintPosition = time;
      _repaint.invalidate();
    }
  }

  void _sync({bool force = false}) {
    if (_size.isEmpty) return;
    final time = widget.position(),
        index = widget.document.activeIndex(time),
        start = widget.document.latestStartedIndex(time);
    if (!force && index == _currentIndex && start == _latestStart) return;
    _currentIndex = index;
    _latestStart = start;
    final lines = widget.document.lines;
    final entries = _manualAnchor != null
        ? buildScrollableRailEntries(lines, _manualAnchor!, index)
        : buildMonetVisibleLineEntries(
            lines: lines,
            currentLineIndex: index,
            activeLine: index < 0 ? null : lines[index],
            recentCompletedLine: getRecentCompletedLine(
              lines: lines,
              currentLineIndex: index,
              currentTime: time,
              getLineEndTime: (line) => line.hints.renderEndTime,
            ),
            upcomingLine: getUpcomingLine(lines, index, time),
            currentTime: time,
          );
    final inputs = MonetLineLayoutInputs(
      fontPx: widget.lyricFontPx,
      translationFontPx: widget.translationFontPx,
      fontStack: _lyricStack,
      translationFontStack: _subtitleStack,
      maxWidthPx: _size.width.roundToDouble() - 2 * _glow - 8,
      fontWeight: _lyric.weight,
      translationFontWeight: _subtitle.weight,
      secondaryTranslationFontWeight: _secondarySubtitle.weight,
      subtitleContentMode: widget.subtitleContentMode,
    );
    final positions = buildPositionedEntries(
      entries: entries,
      // useMonetRailSize stores Math.round(clientWidth/clientHeight); painting retains the actual box.
      railWidth: _size.width.roundToDouble(),
      railHeight: _size.height.roundToDouble(),
      lyricFontPx: widget.lyricFontPx,
      inactiveFontPx: widget.inactiveFontPx,
      glowBufferPx: _glow,
      inputs: inputs,
      cache: _layouts,
      measure: _measure,
    );
    final now = widget.seconds(),
        keys = positions.map((p) => p.entry.key).toSet();
    // AnimatePresence initial=false suppresses nested entry motion only for its first nonempty mount.
    if (positions.isEmpty) {
      for (final row in _rows.values) {
        row.dispose();
      }
      _rows.clear();
      _ordered = [];
      _hasExiting = false;
      _hasPopulatedRail = false;
      _cache.pin({});
      _repaint.invalidate();
      if (!_building && mounted) _changed();
      return;
    }
    final suppressInitial = !_hasPopulatedRail;
    _hasPopulatedRail = true;
    for (final entry in positions) {
      final previous = _rows.remove(entry.entry.key),
          motion =
              previous?.motion ??
              MonetRailMotion(
                entry,
                now,
                manual: _manualAnchor != null,
                suppressInitial: suppressInitial,
              );
      motion.target(entry, now);
      previous?.dispose();
      _rows[entry.entry.key] = _prepareRow(motion, inputs);
    }
    for (final row in _rows.values) {
      if (!keys.contains(row.motion.entry.entry.key)) {
        row.motion.exit(now, manual: _manualAnchor != null);
      }
    }
    _order();
    _pinAndWarm();
    _repaint.invalidate();
    if (!_building && mounted) _changed();
  }
}
