import 'package:flutter/widgets.dart';

import 'monet_portrait_layers.dart';

// Decode before stacking, as MonetPortraitImage.tsx does; a failed/obsolete decode never blanks the frame.
class MonetPortraitImage extends StatefulWidget {
  const MonetPortraitImage({
    super.key,
    this.image,
    this.source,
    this.fadeMs = monetPortraitFadeMs,
  });
  final ImageProvider? image;
  final String? source;
  final int fadeMs;
  @override
  State<MonetPortraitImage> createState() => _MonetPortraitImageState();
}

class _MonetPortraitImageState extends State<MonetPortraitImage> {
  List<MonetPortraitLayer> _layers = [];
  final _images = <String, ImageProvider>{};
  ImageStream? _loading;
  ImageStreamListener? _listener;
  var _generation = 0, _key = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _decode();
  }

  @override
  void didUpdateWidget(MonetPortraitImage old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image || old.source != widget.source) _decode();
  }

  void _cancelLoading() {
    if (_listener != null) _loading?.removeListener(_listener!);
    _listener = null;
    _loading = null;
  }

  void _decode() {
    final generation = ++_generation;
    _cancelLoading();
    final source = widget.source, provider = widget.image;
    if (source == null ||
        source.isEmpty ||
        provider == null ||
        monetPortraitTargetSource(_layers) == source) {
      return;
    }
    final stream = provider.resolve(createLocalImageConfiguration(context));
    _loading = stream;
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, synchronous) {
        if (!mounted || generation != _generation) {
          info.dispose();
          return;
        }
        // The rendered Image takes over the decoded stream, including animated covers at full resolution.
        final key = 'monet-portrait-${++_key}';
        void accept() {
          _images[key] = provider;
          _layers = pushMonetPortraitLayer(_layers, source, key);
          _releaseUnused();
        }

        if (synchronous) {
          accept();
        } else {
          setState(accept);
        }
        info.dispose();
        // Keep the decode lease through handoff so the child joins the already decoded cache entry.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          stream.removeListener(listener);
          if (_loading == stream) {
            _listener = null;
            _loading = null;
          }
        });
      },
      onError: (Object error, StackTrace? stack) {
        // Keep the previous stack, including on a bad URL or revoked URI.
        if (generation == _generation) _cancelLoading();
      },
    );
    _listener = listener;
    stream.addListener(listener);
  }

  void _releaseUnused() {
    final used = _layers.map((l) => l.key).toSet();
    for (final key in _images.keys.toList()) {
      if (!used.contains(key)) _images.remove(key);
    }
  }

  void _settle(String key) {
    if (!mounted ||
        _layers.lastOrNull?.key != key ||
        widget.source == null ||
        widget.source!.isEmpty) {
      return;
    }
    setState(() {
      _layers = settleMonetPortraitLayers(_layers, key);
      _releaseUnused();
    });
  }

  @override
  void dispose() {
    _generation++;
    _cancelLoading();
    _images.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (final layer in _layers)
        _PortraitFade(
          key: ValueKey(layer.key),
          image: _images[layer.key]!,
          visible: widget.source != null && widget.source!.isNotEmpty,
          fadeMs: widget.fadeMs,
          onSettled: () => _settle(layer.key),
        ),
    ],
  );
}

class _PortraitFade extends StatefulWidget {
  const _PortraitFade({
    super.key,
    required this.image,
    required this.visible,
    required this.fadeMs,
    required this.onSettled,
  });
  final ImageProvider image;
  final bool visible;
  final int fadeMs;
  final VoidCallback onSettled;
  @override
  State<_PortraitFade> createState() => _PortraitFadeState();
}

class _PortraitFadeState extends State<_PortraitFade>
    with SingleTickerProviderStateMixin {
  late final _fade =
      AnimationController(
        vsync: this,
        duration: Duration(milliseconds: widget.fadeMs),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onSettled();
      });
  // Framer's easeInOut uses this exact cubic curve.
  late final _opacity = CurvedAnimation(
    parent: _fade,
    curve: const Cubic(.42, 0, .58, 1),
  );
  @override
  void initState() {
    super.initState();
    if (widget.visible) _fade.forward();
  }

  @override
  void didUpdateWidget(_PortraitFade old) {
    super.didUpdateWidget(old);
    _fade.duration = Duration(milliseconds: widget.fadeMs);
    if (widget.visible != old.visible) {
      if (widget.visible) {
        _fade.forward();
      } else {
        _fade.reverse();
      }
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: Image(
      image: widget.image,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    ),
  );
}
