import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../artwork/wall_artwork_image.dart';
import '../../../../artwork/wall_artwork_store.dart';
import '../../../../artwork/wall_poster_artwork.dart';
import 'bravais_art_effect.dart';
import 'bravais_art_program.dart';
import 'bravais_art_style.dart';

// The real card art layer joins source variant handoff and the retained shader. Mosaic's 512px second background remains underneath transparent high-resolution artwork.
class BravaisArtworkLayer extends StatefulWidget {
  const BravaisArtworkLayer({
    super.key,
    required this.program,
    required this.store,
    required this.style,
    required this.cover,
    required this.sizePx,
    this.mosaic = false,
    this.active = true,
  });
  final BravaisArtProgram program;
  final WallArtworkStore store;
  final ValueListenable<BravaisArtStyle> style;
  final String? cover;
  final double sizePx;
  final bool mosaic, active;
  @override
  State<BravaisArtworkLayer> createState() => _BravaisArtworkLayerState();
}

class _BravaisArtworkLayerState extends State<BravaisArtworkLayer> {
  WallPosterArtwork? _artwork;
  late BravaisArtEffect _effect;
  bool _tickerEnabled = true;
  bool get _active => widget.active && _tickerEnabled;
  @override
  void initState() {
    super.initState();
    _effect = BravaisArtEffect(widget.program, widget.style);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _artwork ??= WallPosterArtwork(
      widget.store,
      widget.cover,
      widget.sizePx,
      active: _active,
    );
    _artwork!.setActive(_active);
  }

  @override
  void didUpdateWidget(BravaisArtworkLayer old) {
    super.didUpdateWidget(old);
    if (!identical(old.store, widget.store)) {
      _artwork?.dispose();
      _artwork = WallPosterArtwork(
        widget.store,
        widget.cover,
        widget.sizePx,
        active: _active,
      );
    } else {
      _artwork?.setActive(_active);
      _artwork?.update(widget.cover, widget.sizePx);
    }
    if (!identical(old.program, widget.program) ||
        !identical(old.style, widget.style)) {
      _effect.dispose();
      _effect = BravaisArtEffect(widget.program, widget.style);
    }
  }

  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: _active,
    child: ValueListenableBuilder(
      valueListenable: _artwork!,
      builder: (context, url, _) {
        final standIn = widget.mosaic
            ? widget.store.policy.sized(widget.cover, 512)
            : '';
        final hasStandIn =
            standIn.isNotEmpty && standIn != url && url.isNotEmpty;
        return SizedBox.expand(
          child: ClipRect(
            child: RepaintBoundary(
              child: WallArtworkImage(
                provider: url.isEmpty ? null : widget.store.provider(url),
                underlay: hasStandIn ? widget.store.provider(standIn) : null,
                effect: _effect,
              ),
            ),
          ),
        );
      },
    ),
  );
  @override
  void dispose() {
    _artwork?.dispose();
    _effect.dispose();
    super.dispose();
  }
}
