import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

import '../../../../artwork/wall_artwork_store.dart';
import '../../../../i18n/folia_strings.dart';
import '../../../wall/wall_typography.dart';
import '../artwork/bravais_art_program.dart';
import '../artwork/bravais_artwork_samples.dart';

// One wall owns these resource handles. Card materialization does not create another shader program, clock, locale table or image cache.
class BravaisCardResources {
  const BravaisCardResources({
    required this.store,
    required this.samples,
    required this.program,
    required this.frames,
    required this.nowMs,
    required this.isPlaying,
    required this.typography,
    required this.strings,
    required this.albumAccent,
    required this.albumBlock,
  });
  final WallArtworkStore store;
  final BravaisArtworkSamples samples;
  final BravaisArtProgram program;
  final Listenable frames;
  final double Function() nowMs;
  final ValueListenable<bool> isPlaying;
  final WallTypography typography;
  final FoliaStrings strings;
  final Color albumAccent, albumBlock;
  BravaisCardResources withFrames(Listenable frames) => BravaisCardResources(
    store: store,
    samples: samples,
    program: program,
    frames: frames,
    nowMs: nowMs,
    isPlaying: isPlaying,
    typography: typography,
    strings: strings,
    albumAccent: albumAccent,
    albumBlock: albumBlock,
  );
}
