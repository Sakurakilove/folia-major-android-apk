import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/ui_strings.dart';
import '../glass/liquid_glass.dart';
import 'playback_controller.dart';
import 'playback_progress.dart';

// One finite optical surface contains controls; it never owns an audio output or a frame timer.
class PlaybackBar extends StatelessWidget {
  const PlaybackBar({
    super.key,
    required this.playback,
    required this.frames,
    required this.glass,
    required this.onOpen,
    required this.run,
  });
  final PlaybackController playback;
  final Listenable frames;
  final ui.FragmentProgram glass;
  final VoidCallback onOpen;
  final Future<void> Function(Future<void> Function()) run;
  @override
  Widget build(BuildContext context) {
    final track = playback.track!,
        text = UiStrings(Localizations.localeOf(context).languageCode);
    return LiquidGlass(
      program: glass,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (track.coverPath != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(track.coverPath!),
                        width: 42,
                        height: 42,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Expanded(
                  child: GestureDetector(
                    onTap: onOpen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: text('previous'),
                  onPressed: playback.currentIndex > 0
                      ? () => run(() => playback.skip(-1))
                      : null,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                IconButton.filled(
                  tooltip: text(playback.playing ? 'pause' : 'play'),
                  onPressed: () => run(playback.toggle),
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween(begin: .75, end: 1.0).animate(animation),
                        child: RotationTransition(
                          turns: Tween(
                            begin: -12 / 360,
                            end: 0.0,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                    ),
                    child: Icon(
                      playback.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      key: ValueKey(playback.playing),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: text('next'),
                  onPressed: playback.currentIndex + 1 < playback.tracks.length
                      ? () => run(() => playback.skip(1))
                      : null,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              ],
            ),
            PlaybackProgress(playback: playback, frames: frames),
          ],
        ),
      ),
    );
  }
}
