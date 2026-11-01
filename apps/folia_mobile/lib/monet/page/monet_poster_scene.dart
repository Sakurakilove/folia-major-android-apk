import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../audio/analysis/spectrum_feed.dart';
import '../../i18n/folia_strings.dart';
import '../../lyrics/lyric_document.dart';
import '../../lyrics/subtitle_tracks.dart';
import '../../theme/folia_theme.dart';
import '../audio/monet_audio_overlay.dart';
import '../monet_floating_decor.dart';
import '../../rendering/folia_typography.dart';
import '../rail/monet_rail.dart';
import 'monet_entrance.dart';
import 'monet_description_capsule.dart';
import 'monet_portrait.dart';
import 'monet_poster_layout.dart';
import 'monet_poster_metadata.dart';
import 'monet_tuning.dart';

part 'monet_poster_composition.dart';
part 'monet_poster_columns.dart';

// Full Monet poster content over the persistent shared backdrop; not the rejected prototype's substitute layout.
class MonetPosterScene extends StatefulWidget {
  const MonetPosterScene({
    super.key,
    required this.document,
    required this.position,
    required this.seconds,
    required this.frames,
    required this.tokenProgram,
    required this.audio,
    required this.theme,
    required this.strings,
    required this.tuning,
    required this.resolveColor,
    this.subtitleTheme,
    this.title = '',
    this.artist = '',
    this.album = '',
    this.seed,
    this.cover,
    this.coverSource,
    this.customPortrait,
    this.customPortraitSource,
    this.onTuningChange,
    this.onLineSeek,
    this.subtitleContentMode = SubtitleContentMode.translation,
    this.subtitleFontScale = 1,
    this.fontsEpoch = 0,
    this.showText = true,
    this.staticMode = false,
    this.isPreviewMode = false,
    this.active = true,
  });
  final LyricDocument document;
  final double Function() position, seconds;
  final Listenable frames;
  final ui.FragmentProgram tokenProgram;
  final SpectrumFeed audio;
  final FoliaTheme theme;
  final FoliaTheme? subtitleTheme;
  final FoliaStrings strings;
  final MonetTuning tuning;
  final Color Function(String css) resolveColor;
  final String title, artist, album;
  final String? seed, coverSource, customPortraitSource;
  final ImageProvider? cover, customPortrait;
  final ValueChanged<MonetTuning>? onTuningChange;
  final ValueChanged<double>? onLineSeek;
  final SubtitleContentMode subtitleContentMode;
  final double subtitleFontScale;
  final int fontsEpoch;
  final bool showText, staticMode, isPreviewMode, active;
  @override
  State<MonetPosterScene> createState() => _MonetPosterSceneState();
}

class _MonetPosterSceneState extends State<MonetPosterScene>
    with TickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final _portraitIntro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1850),
  );
  Listenable? _attached;
  double _lastPosition = 0;
  int _introKey = 0;
  bool _showingText = false;
  String get _songIdentifier => widget.seed ?? widget.title;
  @override
  void initState() {
    super.initState();
    _visibility();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attach();
  }

  @override
  void didUpdateWidget(MonetPosterScene old) {
    super.didUpdateWidget(old);
    _visibility();
    if ((old.seed ?? old.title) != _songIdentifier) {
      _introKey++;
      _intro.forward(from: 0);
    }
    _attach();
  }

  void _visibility() {
    if (!_showingText && widget.showText) {
      _intro.forward(from: 0);
      _portraitIntro.forward(from: 0);
    }
    _showingText = widget.showText;
  }

  void _attach() {
    final frames = widget.active && TickerMode.valuesOf(context).enabled
        ? widget.frames
        : null;
    if (_attached == frames) return;
    _attached?.removeListener(_frame);
    _attached = frames;
    _attached?.addListener(_frame);
  }

  void _frame() {
    final next = widget.position();
    if (_lastPosition > 2 && next < .1) {
      setState(() {
        _introKey++;
      });
      _intro.forward(from: 0);
    }
    _lastPosition = next;
  }

  @override
  void dispose() {
    _attached?.removeListener(_frame);
    _intro.dispose();
    _portraitIntro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _composition(context);
}
