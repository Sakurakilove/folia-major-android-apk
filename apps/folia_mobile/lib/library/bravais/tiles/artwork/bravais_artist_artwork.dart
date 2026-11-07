import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../artwork/wall_artwork_store.dart';
import '../../../wall/wall_css_paint.dart';
import '../bravais_card_palette.dart';
import 'bravais_art_program.dart';
import 'bravais_artist_art_motion.dart';
import 'bravais_artist_tone.dart';
import 'bravais_artwork_layer.dart';
import 'bravais_artwork_samples.dart';

// Actual original artist overlay: unknown/black-white/unreadable uses the theme, broken images remove the layer, cached photo tones render directly on mount.
class BravaisArtistArtwork extends StatefulWidget {
  const BravaisArtistArtwork({
    super.key,
    required this.itemKey,
    required this.cover,
    required this.sizePx,
    required this.palette,
    required this.samples,
    required this.program,
    required this.store,
    required this.frames,
    required this.nowMs,
    required this.restored,
    required this.reducedMotion,
    this.active = true,
  });
  final String itemKey;
  final String? cover;
  final double sizePx;
  final BravaisCardPalette palette;
  final BravaisArtworkSamples samples;
  final BravaisArtProgram program;
  final WallArtworkStore store;
  final Listenable frames;
  final double Function() nowMs;
  final bool restored, reducedMotion, active;
  @override
  State<BravaisArtistArtwork> createState() => _BravaisArtistArtworkState();
}

class _BravaisArtistArtworkState extends State<BravaisArtistArtwork> {
  ValueListenable<BravaisArtistTone?>? _tone;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    final url = widget.cover ?? '';
    _tone = url.isEmpty ? null : widget.samples.artist(url);
    _tone?.addListener(_changed);
    if (url.isNotEmpty) widget.samples.requestArtist(url);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(BravaisArtistArtwork old) {
    super.didUpdateWidget(old);
    if (old.cover != widget.cover || !identical(old.samples, widget.samples)) {
      _tone?.removeListener(_changed);
      _bind();
    }
  }

  @override
  Widget build(BuildContext context) =>
      _tone?.value?.kind == BravaisArtistToneKind.unavailable
      ? const SizedBox.shrink()
      : _ArtistBody(
          source: widget,
          light: _tone?.value?.color ?? widget.palette.accent,
        );
  @override
  void dispose() {
    _tone?.removeListener(_changed);
    super.dispose();
  }
}

class _ArtistBody extends StatefulWidget {
  const _ArtistBody({required this.source, required this.light});
  final BravaisArtistArtwork source;
  final Color light;
  @override
  State<_ArtistBody> createState() => _ArtistBodyState();
}

class _ArtistBodyState extends State<_ArtistBody> {
  late final BravaisArtistArtMotion _motion;
  late List<Color> _fallback;
  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _fallback = wallFallbackColors(s.itemKey);
    _motion = BravaisArtistArtMotion(
      frames: s.frames,
      nowMs: s.nowMs,
      palette: s.palette,
      light: widget.light,
      restored: s.restored,
      fallback: s.cover == null || s.cover!.isEmpty,
      fallbackColors: _fallback,
      reducedMotion: s.reducedMotion,
    );
  }

  @override
  void didUpdateWidget(_ArtistBody old) {
    super.didUpdateWidget(old);
    final s = widget.source;
    if (old.source.itemKey != s.itemKey) {
      _fallback = wallFallbackColors(s.itemKey);
    }
    _motion.rebind(s.frames, s.nowMs);
    _motion.update(
      palette: s.palette,
      light: widget.light,
      restored: s.restored,
      fallback: s.cover == null || s.cover!.isEmpty,
      fallbackColors: _fallback,
      reducedMotion: s.reducedMotion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.source;
    return BravaisArtworkLayer(
      program: s.program,
      store: s.store,
      style: _motion,
      cover: s.cover,
      sizePx: s.sizePx,
      active: s.active,
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }
}
