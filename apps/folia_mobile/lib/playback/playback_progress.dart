import 'package:flutter/material.dart';

import 'playback_controller.dart';

// Only this bounded painter listens to the progress clock; the library remains cached.
class PlaybackProgress extends StatelessWidget {
  const PlaybackProgress({
    super.key,
    required this.playback,
    required this.frames,
  });
  final PlaybackController playback;
  final Listenable frames;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        if (playback.duration > 0) {
          playback.seek(
            d.localPosition.dx / bounds.maxWidth * playback.duration,
          );
        }
      },
      onHorizontalDragUpdate: (d) {
        if (playback.duration > 0) {
          playback.seek(
            (d.localPosition.dx / bounds.maxWidth).clamp(0.0, 1.0) *
                playback.duration,
          );
        }
      },
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ProgressPainter(playback, frames),
          child: const SizedBox(height: 28, width: double.infinity),
        ),
      ),
    ),
  );
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter(this.player, Listenable frames) : super(repaint: frames);
  final PlaybackController player;
  @override
  void paint(Canvas c, Size size) {
    final fraction = player.duration > 0
        ? (player.position / player.duration).clamp(0.0, 1.0)
        : 0.0;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 12, size.width, 4),
      const Radius.circular(2),
    );
    c.drawRRect(track, Paint()..color = const Color(0x24355d69));
    c.save();
    c.clipRRect(track);
    c.drawRect(
      Rect.fromLTWH(0, 12, size.width * fraction, 4),
      Paint()..color = const Color(0xff294e59),
    );
    c.restore();
    c.drawCircle(
      Offset(size.width * fraction, 14),
      4,
      Paint()..color = const Color(0xff294e59),
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter old) => true;
}
