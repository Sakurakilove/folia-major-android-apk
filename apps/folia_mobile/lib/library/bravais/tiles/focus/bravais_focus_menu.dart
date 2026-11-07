part of 'bravais_focus_body.dart';

// The menu is clipped by its own poster as in the original; it is not a Material route or a new full-screen popup.
class _FocusMenu extends StatefulWidget {
  const _FocusMenu({
    required this.slotKey,
    required this.entries,
    required this.actions,
    required this.strings,
    required this.typography,
    required this.accent,
  });
  final String slotKey;
  final List<BravaisEntryMenuItem> entries;
  final BravaisCardActions actions;
  final FoliaStrings strings;
  final WallTypography typography;
  final Color accent;
  @override
  State<_FocusMenu> createState() => _FocusMenuState();
}

class _FocusMenuState extends State<_FocusMenu> {
  bool _open = false;
  static const _white = Color(0xffffffff);
  Widget _entry(BravaisEntryMenuItem entry) => BravaisControl(
    label: entry.label,
    onPressed: () {
      setState(() => _open = false);
      widget.actions.runMenu(widget.slotKey, entry.id);
    },
    builder: (_, hover, _) => Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: hover ? _white.withValues(alpha: .14) : const Color(0x00000000),
      ),
      child: Text(
        entry.label,
        textScaler: TextScaler.noScaling,
        style: widget.typography.style(
          13,
          color: entry.danger
              ? Color.lerp(_white, const Color(0xfff87171), .8)!
              : _white,
          weight: 650,
        ),
      ),
    ),
  );
  Widget _panel() => IntrinsicWidth(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          constraints: const BoxConstraints(minWidth: 180),
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(color: Color.fromRGBO(0, 0, 0, .55)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widget.entries.length; i++) ...[
                if (i > 0) const SizedBox(height: 2),
                _entry(widget.entries[i]),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Positioned(
      top: 18,
      right: 18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          BravaisChromeButton(
            ink: _white,
            accent: w.accent,
            typography: w.typography,
            label: w.strings.t('libraryBravaisCollection.more'),
            minimumHeight: 36,
            horizontalPadding: 10,
            expanded: _open,
            onPressed: () => setState(() => _open = !_open),
            builder: (_) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [FoliaIcon('MoreHorizontal', color: _white, size: 18)],
            ),
          ),
          if (_open) ...[const SizedBox(height: 6), _panel()],
        ],
      ),
    );
  }
}
