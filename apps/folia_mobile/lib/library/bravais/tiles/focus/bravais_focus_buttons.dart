part of 'bravais_focus_body.dart';

// Discrete playback/queue controls; retained reveal owns only their finite layer animation.
extension _FocusButtons on _BravaisFocusBodyState {
  Widget _icon(String name, {bool filled = false, double size = 18}) =>
      FoliaIcon(name, color: widget.ink, size: size, filled: filled);
  Widget _enqueue() {
    final w = widget,
        s = w.strings,
        label = s.t(
          w.queued ? 'libraryBravais.inQueue' : 'libraryBravais.addToQueue',
        ),
        hoverLabel = s.t('libraryBravais.insertIntoQueue');
    Widget text(String icon, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _icon(icon),
        const SizedBox(width: 8),
        Text(label, textScaler: TextScaler.noScaling),
      ],
    );
    return BravaisChromeButton(
      ink: w.ink,
      accent: w.accent,
      typography: w.typography,
      label: label,
      highlightLabel: w.queued && !w.current ? hoverLabel : null,
      onPressed: w.item.unavailable ? null : () => w.actions.enqueue(w.slotKey),
      builder: (hover) {
        final swaps = w.queued && !w.current;
        return Semantics(
          label: swaps && hover ? hoverLabel : label,
          child: swaps
              ? Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Visibility(
                      visible: !hover,
                      maintainAnimation: true,
                      maintainState: true,
                      maintainSize: true,
                      child: text('Check', label),
                    ),
                    Visibility(
                      visible: hover,
                      maintainAnimation: true,
                      maintainState: true,
                      maintainSize: true,
                      child: text('Plus', hoverLabel),
                    ),
                  ],
                )
              : text(w.queued ? 'Check' : 'Plus', label),
        );
      },
    );
  }

  Widget _buttons(bool playing) {
    final w = widget,
        toggles = w.current && w.actions.togglesCurrent,
        playLabel = w.strings.t(
          toggles
              ? (playing
                    ? 'libraryBravais.pausePlayback'
                    : 'libraryBravais.resumePlayback')
              : 'libraryBravais.playNow',
        );
    return BravaisFocusRevealLayer(
      reveal: _reveal,
      child: RepaintBoundary(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            BravaisChromeButton(
              ink: w.ink,
              accent: w.accent,
              typography: w.typography,
              label: playLabel,
              iconOnly: true,
              onPressed: w.item.unavailable && !toggles
                  ? null
                  : () => w.actions.play(w.slotKey),
              builder: (_) => _icon(
                toggles && playing ? 'Pause' : 'Play',
                size: 20,
                filled: true,
              ),
            ),
            if (w.current && w.actions.enterPlayback != null)
              BravaisChromeButton(
                ink: w.ink,
                accent: w.accent,
                typography: w.typography,
                label: w.strings.t(
                  w.entersLattice
                      ? 'libraryBravais.enterLattice'
                      : 'libraryBravais.enterPlayer',
                ),
                iconOnly: true,
                onPressed: w.actions.enterPlayback,
                builder: (_) => _icon('Maximize2', size: 20),
              ),
            _enqueue(),
          ],
        ),
      ),
    );
  }
}

Widget _focusButtons(_BravaisFocusBodyState state, bool playing) =>
    state._buttons(playing);
