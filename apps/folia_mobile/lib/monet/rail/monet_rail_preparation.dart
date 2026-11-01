part of 'monet_rail.dart';

// Preparation logic stays outside the rail widget assembly.
extension _MonetRailPreparation on _MonetRailState {
  MonetPaintRow _prepareRow(
    MonetRailMotion motion,
    MonetLineLayoutInputs inputs,
  ) {
    final entry = motion.entry, line = entry.entry.line;
    final font = '${_lyric.weight} ${widget.lyricFontPx}px $_lyricStack',
        // The -8/180px floor belongs to measurement only. DOM inline text occupies the actual content box.
        width = math.max(
          0.0,
          _size.width - 2 * _glow,
        );
    final flow = _measure.flow(line, font, width, entry.layout.lineHeightPx);
    final typography = _lyric.withHeight(
      entry.layout.lineHeightPx / widget.lyricFontPx,
    );
    final colors = resolveTokenColorMap(
      buildMonetDisplayTokens(line),
      buildWordColorRangesFromMatchers(line.text, _matchers),
    );
    final accent = line.isChorus
        ? _mix(_primary, _accent, .48)
        : _primary.withValues(alpha: .98);
    final runs = flow.runs
        .map(
          (run) => MonetPaintRun(
            run,
            _cache.key(
              run.token.text,
              widget.lyricFontPx,
              MediaQuery.devicePixelRatioOf(context),
              line.isChorus,
              run.widthConstraint,
              typography,
              !run.token.timed,
            ),
            colors[run.token.key] == null
                ? accent
                : widget.resolveColor(colors[run.token.key]!),
            widget.tokenProgram.fragmentShader(),
          ),
        )
        .toList();
    final subtitles = <TextPainter>[];
    for (var i = 0; i < entry.layout.subtitleTracks.length; i++) {
      final track = entry.layout.subtitleTracks[i],
          font = (i == 0 ? _subtitle : _secondarySubtitle).withHeight(
            track.lineHeightPx / track.fontPx,
          );
      subtitles.add(
        TextPainter(
          text: TextSpan(
            text: track.text,
            style: font.style(
              track.fontPx,
              color: _primary.withValues(
                alpha: .68 * (i == 0 ? 1 : secondaryTrackOpacity),
              ),
            ),
          ),
          textDirection: font.direction,
          locale: font.locale,
        )..layout(maxWidth: width),
      );
    }
    TextPainter? staticParagraph;
    if (_manualAnchor != null && entry.entry.index != _currentIndex) {
      staticParagraph = TextPainter(
        text: TextSpan(
          style: typography.style(widget.lyricFontPx),
          children: [
            for (final token in buildMonetDisplayTokens(line))
              TextSpan(
                text: token.text,
                style: TextStyle(
                  color: token.timed
                      ? colors[token.key] == null
                            ? accent
                            : widget.resolveColor(colors[token.key]!)
                      : _primary.withValues(alpha: entry.tone.baseAlpha),
                ),
              ),
          ],
        ),
        textDirection: _lyric.direction,
      )..layout(maxWidth: width);
    }
    final staticTokens = staticParagraph == null
        ? flow.staticParagraph(
            typography
                .style(
                  widget.lyricFontPx,
                  color: _primary.withValues(alpha: entry.tone.baseAlpha),
                )
                .copyWith(
                  shadows: entry.entry.status == 'active'
                      ? [
                          cssTextShadow(
                            _background.withValues(alpha: .22),
                            const Offset(0, 14),
                            34,
                          ),
                        ]
                      : null,
                ),
          )
        : null;
    return MonetPaintRow(
      motion,
      runs,
      subtitles,
      staticParagraph,
      flow,
      typography,
      staticTokens,
    );
  }

  Color _mix(Color a, Color b, double amount) => Color.fromRGBO(
    ((a.r + (b.r - a.r) * amount) * 255).round(),
    ((a.g + (b.g - a.g) * amount) * 255).round(),
    ((a.b + (b.b - a.b) * amount) * 255).round(),
    1,
  );

  void _order() {
    _ordered = _rows.values.toList()
      ..sort(
        (a, b) => a.motion.entry.tone.zIndex != b.motion.entry.tone.zIndex
            ? a.motion.entry.tone.zIndex.compareTo(b.motion.entry.tone.zIndex)
            : a.motion.entry.entry.index.compareTo(b.motion.entry.entry.index),
      );
    _hasExiting = _ordered.any((row) => row.motion.exiting);
  }

  void _pinAndWarm() {
    _cache.pin({
      for (final row in _ordered)
        if (row.staticParagraph == null)
          for (final run in row.runs) run.cacheKey,
    });
    final priority = [..._ordered]
      ..sort(
        (a, b) => a.motion.entry.entry.offset.abs().compareTo(
          b.motion.entry.entry.offset.abs(),
        ),
      );
    for (final row in priority) {
      if (row.staticParagraph != null) continue;
      for (final run in row.runs) {
        if (_cache.get(run.cacheKey) != null ||
            _cache.isPreparing(run.cacheKey)) {
          continue;
        }
        _cache
            .prepare(
              run.run.token.text,
              widget.lyricFontPx,
              MediaQuery.devicePixelRatioOf(context),
              row.motion.entry.entry.line.isChorus,
              run.run.widthConstraint,
              row.typography,
              !run.run.token.timed,
            )
            .then((_) {
              if (mounted) _repaint.invalidate();
            });
      }
    }
  }
}
