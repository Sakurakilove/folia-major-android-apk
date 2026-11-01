part of 'monet_poster_scene.dart';

// Source layers stay independent: intro-keyed decor/text/audio over the same persistent portrait and backdrop host.
extension _MonetPosterComposition on _MonetPosterSceneState {
  Widget _composition(BuildContext context) {
    if (!widget.showText) return const SizedBox.expand();
    final viewport = MediaQuery.sizeOf(context),
        primary = widget.resolveColor(widget.theme.primaryColor),
        accent = widget.resolveColor(widget.theme.accentColor),
        secondary = widget.resolveColor(widget.theme.secondaryColor),
        background = widget.resolveColor(widget.theme.backgroundColor),
        typography = FoliaTypography.fromTheme(
          widget.theme,
          fallbackWeight: 400,
          height: 1.5,
          fontsEpoch: widget.fontsEpoch,
          locale: Localizations.maybeLocaleOf(context),
        );
    final custom = widget.tuning.portraitSource == 'custom',
        portraitImage = custom
            ? widget.customPortrait ?? widget.cover
            : widget.cover ?? widget.customPortrait,
        portraitSource = custom
            ? widget.customPortraitSource ?? widget.coverSource
            : widget.coverSource ?? widget.customPortraitSource;
    final description = widget.theme.description?.trim(),
        name = widget.theme.name.trim(),
        capsule = description?.isNotEmpty == true
            ? description!
            : name.isNotEmpty
            ? name
            : 'Monet';
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = MonetPosterLayout(
          viewportWidth: viewport.width,
          viewportHeight: viewport.height,
          containerWidth: constraints.maxWidth,
          tuning: widget.tuning,
          subtitleFontScale: widget.subtitleFontScale,
        );
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MonetEntrance(
                clock: _intro,
                duration: 2.2,
                delay: 0,
                curve: const Cubic(0, 0, .58, 1),
                child: MonetFloatingDecor(
                  key: ValueKey('decor-$_introKey'),
                  secondaryColor: secondary,
                  lyricsIcons: widget.theme.lyricsIcons,
                  frames: widget.frames,
                  seconds: widget.seconds,
                  staticMode: widget.staticMode,
                ),
              ),
              Center(
                child: SizedBox(
                  width: layout.rowWidth,
                  height: constraints.maxHeight,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      _textColumn(
                        layout,
                        typography,
                        primary,
                        secondary,
                        background,
                        accent,
                        capsule,
                      ),
                      if (layout.showPortrait)
                        _portraitColumn(
                          layout,
                          viewport,
                          primary,
                          accent,
                          background,
                          portraitImage,
                          portraitSource,
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.tuning.showAudioVisualization)
                Positioned(
                  left: 0,
                  bottom: 0,
                  width: layout.audioWidth,
                  height: 40,
                  child: MonetEntrance(
                    clock: _intro,
                    duration: 1.2,
                    delay: .8,
                    offset: const Offset(0, 15),
                    child: ClipRect(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: layout.audioPaddingX,
                        ),
                        child: MonetAudioOverlay(
                          audio: widget.audio,
                          frames: widget.frames,
                          seconds: widget.seconds,
                          primaryColor: primary,
                          mode: widget.tuning.audioStyle,
                          staticMode: widget.staticMode,
                          isPreviewMode: widget.isPreviewMode,
                          active: widget.active,
                        ),
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
}

class _BleedingRail extends StatelessWidget {
  const _BleedingRail({
    required this.width,
    required this.contentWidth,
    required this.height,
    required this.child,
  });
  final double width, contentWidth, height;
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: contentWidth,
    height: height,
    child: OverflowBox(
      alignment: Alignment.center,
      minWidth: width,
      maxWidth: width,
      minHeight: height,
      maxHeight: height,
      child: child,
    ),
  );
}
