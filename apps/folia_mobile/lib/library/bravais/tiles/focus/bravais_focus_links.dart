part of 'bravais_focus_body.dart';

// Links follow the original wrap order and punctuation, including the leading duration separator when no other metadata exists.
class _FocusLinks extends StatelessWidget {
  const _FocusLinks({
    required this.slotKey,
    required this.item,
    required this.actions,
    required this.typography,
    required this.ink,
  });
  final String slotKey;
  final BravaisItem item;
  final BravaisCardActions actions;
  final WallTypography typography;
  final Color ink;
  @override
  Widget build(BuildContext context) {
    final artists = item.artists ?? const <String>[],
        style = typography.style(17, color: ink, weight: 650);
    Widget separator(String text) => Opacity(
      opacity: .5,
      child: Text(text, style: style, textScaler: TextScaler.noScaling),
    );
    Widget label(String text, VoidCallback? action, {bool tabular = false}) {
      final body = Text(
        cssNormalText(text),
        textScaler: TextScaler.noScaling,
        style: style.copyWith(
          fontFeatures: tabular
              ? const [ui.FontFeature.tabularFigures()]
              : null,
        ),
      );
      if (action == null) return body;
      return BravaisControl(
        onPressed: action,
        label: text,
        builder: (context, hover, focused) => DefaultTextStyle(
          style: style.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: ink.withValues(alpha: ink.a * (hover ? 1 : .35)),
          ),
          child: body,
        ),
      );
    }

    return Opacity(
      opacity: .85,
      child: WallBaselineWrap(
        spacing: 10,
        runSpacing: 6,
        children: [
          for (var i = 0; i < artists.length; i++) ...[
            if (i > 0) separator(','),
            label(
              artists[i],
              actions.canOpenArtist(item.key, i)
                  ? () => actions.openArtist(slotKey, i)
                  : null,
            ),
          ],
          if (item.album != null && item.album!.isNotEmpty) ...[
            if (artists.isNotEmpty) separator('·'),
            label(
              item.album!,
              actions.canOpenAlbum(item.key)
                  ? () => actions.openAlbum(slotKey)
                  : null,
            ),
          ],
          if (item.durationLabel != null && item.durationLabel!.isNotEmpty) ...[
            separator('·'),
            label(item.durationLabel!, null, tabular: true),
          ],
        ],
      ),
    );
  }
}
