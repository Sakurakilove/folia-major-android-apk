part of 'monet_poster_scene.dart';

// Poster text and persistent portrait columns retain separate source lifetimes.
extension _MonetPosterColumns on _MonetPosterSceneState {
  Widget _textColumn(
    MonetPosterLayout layout,
    FoliaTypography typography,
    Color primary,
    Color secondary,
    Color background,
    Color accent,
    String capsule,
  ) => Align(
    alignment: Alignment.centerLeft,
    child: SizedBox(
      width: layout.textWidth,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: layout.paddingX,
          vertical: layout.paddingY,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonetPosterMetadata(
              layout: layout,
              clock: _intro,
              typography: typography,
              primary: primary,
              secondary: secondary,
              background: background,
              artist: widget.artist,
              title: widget.title,
              album: widget.album,
            ),
            MonetEntrance(
              clock: _intro,
              duration: 1.2,
              delay: .65,
              offset: const Offset(0, 20),
              child: _BleedingRail(
                width: layout.railWidth,
                contentWidth: layout.contentWidth,
                height: layout.railHeight,
                child: MonetRail(
                  key: ValueKey('rail-$_introKey'),
                  document: widget.document,
                  position: widget.position,
                  seconds: widget.seconds,
                  frames: widget.frames,
                  tokenProgram: widget.tokenProgram,
                  theme: widget.theme,
                  resolveColor: widget.resolveColor,
                  lyricFontPx: layout.lyricFontPx,
                  inactiveFontPx: layout.inactiveFontPx,
                  translationFontPx: layout.translationFontPx,
                  subtitleTheme: widget.subtitleTheme,
                  subtitleContentMode: widget.subtitleContentMode,
                  keywordColoringEnabled: widget.tuning.keywordColoringEnabled,
                  layoutScale: layout.scale,
                  fontsEpoch: widget.fontsEpoch,
                  onLineSeek: widget.onLineSeek,
                  seekDisabled: widget.isPreviewMode,
                  active: widget.active,
                ),
              ),
            ),
            if (widget.tuning.showDescription)
              MonetEntrance(
                clock: _intro,
                duration: 1,
                delay: .95,
                scale: .9,
                offset: const Offset(0, 10),
                child: MonetDescriptionCapsule(
                  label: capsule,
                  primary: primary,
                  background: background,
                  accent: accent,
                  typography: typography,
                ),
              ),
          ],
        ),
      ),
    ),
  );
  Widget _portraitColumn(
    MonetPosterLayout layout,
    Size viewport,
    Color primary,
    Color accent,
    Color background,
    ImageProvider? portraitImage,
    String? portraitSource,
  ) => Positioned(
    left: layout.textWidth + 12,
    right: layout.portraitPaddingRight,
    top: 0,
    bottom: 0,
    child: Center(
      child: Align(
        alignment: viewport.width >= 1024
            ? Alignment.centerRight
            : Alignment.center,
        child: MonetEntrance(
          clock: _portraitIntro,
          duration: 1.6,
          delay: .25,
          offset: const Offset(50, 0),
          scale: .95,
          rotation: .017453292519943295,
          child: MonetPortrait(
            baseWidth: layout.portraitInnerWidth,
            tuning: widget.tuning,
            primary: primary,
            accent: accent,
            background: background,
            chaotic: widget.theme.animationIntensity == 'chaotic',
            strings: widget.strings,
            image: portraitImage,
            source: portraitSource,
            onTuningChange: widget.onTuningChange,
          ),
        ),
      ),
    ),
  );
}
