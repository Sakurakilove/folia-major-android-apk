import 'package:flutter/widgets.dart';

import '../../rendering/css_shadows.dart';
import '../../rendering/folia_typography.dart';
import 'monet_entrance.dart';
import 'monet_poster_layout.dart';

// Original poster header/title/album/capsule boxes, including the title's padded clipping and local negative margins.
class MonetPosterMetadata extends StatelessWidget {
  const MonetPosterMetadata({
    super.key,
    required this.layout,
    required this.clock,
    required this.typography,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.artist,
    required this.title,
    required this.album,
  });
  final MonetPosterLayout layout;
  final AnimationController clock;
  final FoliaTypography typography;
  final Color primary, secondary, background;
  final String artist, title, album;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: layout.headerWidth,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MonetEntrance(
          clock: clock,
          duration: 1.2,
          delay: .15,
          offset: const Offset(-30, -10),
          child: Text(
            artist.trim().isEmpty ? 'Monet' : artist.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography
                .withHeight(1.5)
                .style(
                  layout.artistFontPx,
                  color: primary.withValues(alpha: .96),
                )
                .copyWith(fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 6),
        MonetEntrance(
          clock: clock,
          duration: 1.5,
          delay: .5,
          scale: 0,
          scaleYOnly: true,
          fade: false,
          origin: Alignment.topCenter,
          child: Container(
            width: 1,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primary.withValues(alpha: .72),
                  primary.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        MonetEntrance(
          clock: clock,
          duration: 1.3,
          delay: .3,
          offset: const Offset(-40, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _PaddedTitle(
                text: title.isEmpty ? 'Monet' : title,
                fontPx: layout.titleFontPx,
                typography: FoliaTypography(
                  families: typography.families,
                  weight: 600,
                  height: 1.06,
                  fontsEpoch: typography.fontsEpoch,
                  locale: typography.locale,
                  direction: typography.direction,
                ),
                primary: primary,
                background: background,
              ),
              Text(
                (album.trim().isEmpty ? 'Monet' : album.trim()).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography
                    .withHeight(20 / 14)
                    .style(14, color: secondary.withValues(alpha: .84)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PaddedTitle extends StatelessWidget {
  const _PaddedTitle({
    required this.text,
    required this.fontPx,
    required this.typography,
    required this.primary,
    required this.background,
  });
  final String text;
  final double fontPx;
  final FoliaTypography typography;
  final Color primary, background;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = typography
          .style(fontPx, color: primary)
          .copyWith(
            shadows: [
              cssTextShadow(
                background.withValues(alpha: .28),
                const Offset(0, 14),
                36,
              ),
            ],
          );
      final paragraph = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 2,
        ellipsis: '…',
        textDirection: typography.direction,
        locale: typography.locale,
      )..layout(maxWidth: constraints.maxWidth);
      final height = paragraph.height;
      paragraph.dispose();
      return SizedBox(
        height: height + fontPx * .13,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: -fontPx * .25,
              height: height + fontPx * .5,
              child: ClipRect(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: fontPx * .25),
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                    textDirection: typography.direction,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
