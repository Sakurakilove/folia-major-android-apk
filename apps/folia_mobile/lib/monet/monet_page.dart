import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/ui_strings.dart';
import '../playback/playback_controller.dart';
import 'monet_scene.dart';
import 'monet_particles.dart';

// The page is a native scene; glyph masks and particles remain isolated from UI state rebuilds.
class MonetPage extends StatelessWidget {
  const MonetPage({
    super.key,
    required this.playback,
    required this.frames,
    required this.seconds,
    required this.words,
    required this.onOpenLyrics,
  });
  final PlaybackController playback;
  final Listenable frames;
  final double Function() seconds;
  final ui.FragmentProgram words;
  final VoidCallback onOpenLyrics;
  @override
  Widget build(BuildContext context) {
    final track = playback.track,
        text = UiStrings(Localizations.localeOf(context).languageCode);
    return RepaintBoundary(
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xffd9e8ed),
                    Color(0xffb2ccdf),
                    Color(0xffe8edf0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: MonetParticles(seconds, frames)),
            ),
          ),
          Positioned(
            left: 28,
            right: 24,
            top: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track?.artist ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    color: Color(0xff34545b),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  track?.title ?? '',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff21393d),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned.fill(
            top: 170,
            bottom: 154,
            child: playback.lyrics.lines.isEmpty
                ? Center(
                    child: TextButton.icon(
                      onPressed: track == null ? null : onOpenLyrics,
                      icon: const Icon(Icons.lyrics_outlined),
                      label: Text(text('noLyrics')),
                    ),
                  )
                : RepaintBoundary(
                    child: MonetScene(
                      playback: playback,
                      frames: frames,
                      seconds: seconds,
                      program: words,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
