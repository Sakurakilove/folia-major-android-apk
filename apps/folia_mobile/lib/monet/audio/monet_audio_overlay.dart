import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../audio/analysis/spectrum_feed.dart';
import '../../audio/analysis/spectrum_snapshot.dart';
import 'monet_audio_geometry.dart';
import 'monet_audio_profile.dart';

// The original overlay consumes the shared FFI snapshot; its native lease exists only for visible live animation.
class MonetAudioOverlay extends StatefulWidget {
  const MonetAudioOverlay({
    super.key,
    required this.audio,
    required this.frames,
    required this.seconds,
    required this.primaryColor,
    required this.mode,
    this.staticMode = false,
    this.isPreviewMode = false,
    this.active = true,
  });
  final SpectrumFeed audio;
  final Listenable frames;
  final double Function() seconds;
  final Color primaryColor;
  final String mode;
  final bool staticMode, isPreviewMode, active;
  @override
  State<MonetAudioOverlay> createState() => _MonetAudioOverlayState();
}

class _MonetAudioOverlayState extends State<MonetAudioOverlay> {
  final _geometry = MonetAudioGeometry();
  void Function()? _release;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lease();
  }

  @override
  void didUpdateWidget(MonetAudioOverlay old) {
    super.didUpdateWidget(old);
    if (old.audio != widget.audio) {
      _release?.call();
      _release = null;
    }
    _lease();
  }

  void _lease() {
    final wanted =
        widget.active &&
        TickerMode.valuesOf(context).enabled &&
        !widget.staticMode &&
        !widget.isPreviewMode;
    if (wanted && _release == null) _release = widget.audio.acquire();
    if (!wanted) {
      _release?.call();
      _release = null;
    }
  }

  @override
  void dispose() {
    _release?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _AudioPainter(
        _geometry,
        widget.audio.snapshot,
        widget.primaryColor,
        widget.mode,
        widget.seconds,
        widget.staticMode || widget.isPreviewMode,
        widget.active ? widget.frames : null,
      ),
      child: const SizedBox.expand(),
    ),
  );
}

class _AudioPainter extends CustomPainter {
  _AudioPainter(
    this.geometry,
    this.audio,
    this.primary,
    this.mode,
    this.seconds,
    this.staticMode,
    Listenable? frames,
  ) : super(repaint: staticMode ? null : frames);
  final MonetAudioGeometry geometry;
  final SpectrumSnapshot audio;
  final Color primary;
  final String mode;
  final double Function() seconds;
  final bool staticMode;
  final _stroke = Path(), _area = Path(), _ink = Paint(), _fill = Paint();
  Size? _size;

  void _paints(Size size) {
    if (_size == size) return;
    _size = size;
    _ink.style = mode == 'line' ? PaintingStyle.stroke : PaintingStyle.fill;
    _ink.strokeWidth = mode == 'line' ? 2 : 1.5;
    _ink.strokeCap = StrokeCap.round;
    if (staticMode) {
      _ink.shader = null;
      _ink.color = primary.withValues(alpha: mode == 'line' ? .96 : .9);
    } else {
      _ink.shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, 0),
        [
          primary.withValues(alpha: .72),
          primary.withValues(alpha: .94),
          primary.withValues(alpha: .72),
        ],
        const [0, .5, 1],
      );
    }
    _fill.shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
      primary.withValues(alpha: .24),
      primary.withValues(alpha: 0),
    ]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _paints(size);
    geometry.update(
      audio: audio,
      width: size.width,
      height: size.height,
      nowMs: seconds() * 1000,
      line: mode == 'line',
      staticMode: staticMode,
    );
    if (mode == 'line') {
      _stroke.reset();
      _stroke.moveTo(geometry.x[0], geometry.y[0]);
      for (var i = 0; i < monetAudioBarCount - 1; i++) {
        _stroke.quadraticBezierTo(
          geometry.x[i],
          geometry.y[i],
          (geometry.x[i] + geometry.x[i + 1]) / 2,
          (geometry.y[i] + geometry.y[i + 1]) / 2,
        );
      }
      _stroke.lineTo(geometry.x.last, geometry.y.last);
      _area.reset();
      _area.addPath(_stroke, Offset.zero);
      _area.lineTo(size.width, size.height);
      _area.lineTo(0, size.height);
      _area.close();
      canvas.drawPath(_area, _fill);
      canvas.drawPath(_stroke, _ink);
    } else {
      for (var i = 0; i < monetAudioBarCount; i++) {
        canvas.drawRect(
          Rect.fromLTWH(
            geometry.x[i],
            geometry.y[i],
            geometry.barWidth,
            size.height - geometry.y[i],
          ),
          _ink,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_AudioPainter old) => true;
}
