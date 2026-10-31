import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../library/library_wall.dart';
import '../monet/monet_page.dart';
import '../playback/playback_bar.dart';
import '../playback/playback_controller.dart';
import 'frame_signal.dart';
import 'ui_strings.dart';

// Visibility controls one ticker; native audio survives independently while all hidden rendering stops.
class ClientShell extends StatefulWidget {
  const ClientShell({super.key, required this.words, required this.glass});
  final ui.FragmentProgram words, glass;
  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final playback = PlaybackController(),
      frames = FrameSignal(),
      inactiveFrames = ChangeNotifier();
  late final Ticker ticker = createTicker((_) => frames.tick());
  late final viewTransition =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
      )..addStatusListener((_) {
        if (mounted) {
          setState(() {});
          syncTicker();
        }
      });
  bool playerView = false, foreground = true;
  String? lastPlaybackError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    playback.addListener(changed);
    playback.connect();
  }

  void changed() {
    if (!mounted) return;
    setState(() {});
    syncTicker();
    if (playback.error != null && playback.error != lastPlaybackError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                UiStrings(Localizations.localeOf(context).languageCode)(
                  'playbackError',
                ),
              ),
            ),
          );
        }
      });
    }
    lastPlaybackError = playback.error;
  }

  void syncTicker() {
    final wanted =
        foreground &&
        (playerView || viewTransition.isAnimating || playback.playing);
    if (wanted && !ticker.isActive) ticker.start();
    if (!wanted && ticker.isActive) ticker.stop();
  }

  void showPlayer(bool value) {
    setState(() => playerView = value);
    if (value) {
      viewTransition.forward();
    } else {
      viewTransition.reverse();
    }
    syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    syncTicker();
  }

  Future<void> run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    viewTransition.dispose();
    ticker.dispose();
    playback.removeListener(changed);
    playback.dispose();
    frames.dispose();
    inactiveFrames.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = UiStrings(Localizations.localeOf(context).languageCode),
        track = playback.track;
    return PopScope(
      canPop: !playerView,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) showPlayer(false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xffdde8ed),
        body: SafeArea(
          child: Stack(
            children: [
              Stack(
                children: [
                  Offstage(
                    offstage: playerView && !viewTransition.isAnimating,
                    child: IgnorePointer(
                      ignoring: playerView,
                      child: FadeTransition(
                        opacity: ReverseAnimation(viewTransition),
                        child: RepaintBoundary(
                          child: playback.tracks.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(text('empty')),
                                      const SizedBox(height: 16),
                                      FilledButton.icon(
                                        onPressed: () =>
                                            run(playback.importAudio),
                                        icon: const Icon(
                                          Icons.audio_file_outlined,
                                        ),
                                        label: Text(text('openAudio')),
                                      ),
                                    ],
                                  ),
                                )
                              : LibraryWall(
                                  tracks: playback.tracks,
                                  active:
                                      !playerView || viewTransition.isAnimating,
                                  onSelect: (index) => run(() async {
                                    await playback.select(index);
                                    showPlayer(true);
                                  }),
                                ),
                        ),
                      ),
                    ),
                  ),
                  Offstage(
                    offstage: !playerView && !viewTransition.isAnimating,
                    child: IgnorePointer(
                      ignoring: !playerView,
                      child: FadeTransition(
                        opacity: viewTransition,
                        child: MonetPage(
                          playback: playback,
                          frames: playerView || viewTransition.isAnimating
                              ? frames
                              : inactiveFrames,
                          seconds: () => frames.seconds,
                          words: widget.words,
                          onOpenLyrics: () => run(playback.importLyrics),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 12,
                right: 12,
                top: 8,
                child: Row(
                  children: [
                    if (playerView)
                      IconButton(
                        tooltip: text('back'),
                        onPressed: () => showPlayer(false),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    Text(
                      playerView ? text('player') : text('library'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: text('openAudio'),
                      onPressed: () => run(playback.importAudio),
                      icon: const Icon(Icons.add_rounded),
                    ),
                    if (track != null)
                      IconButton(
                        tooltip: text('openLyrics'),
                        onPressed: () => run(playback.importLyrics),
                        icon: const Icon(Icons.lyrics_outlined),
                      ),
                  ],
                ),
              ),
              if (track != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: PlaybackBar(
                    playback: playback,
                    frames: frames,
                    glass: widget.glass,
                    onOpen: () => showPlayer(!playerView),
                    run: run,
                  ),
                ),
              if (!ui.ImageFilter.isShaderFilterSupported)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 150,
                  child: Text(
                    text('opticsFallback'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
