import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../i18n/folia_strings.dart';
import '../../../../rendering/css_text.dart';
import '../../../../rendering/folia_icons.dart';
import '../../../wall/wall_title.dart';
import '../../../wall/wall_baseline_wrap.dart';
import '../../../wall/wall_typography.dart';
import '../bravais_control.dart';
import 'bravais_focus_actions.dart';
import 'bravais_focus_reveal.dart';
import '../bravais_item.dart';

part 'bravais_focus_links.dart';
part 'bravais_focus_buttons.dart';
part 'bravais_focus_menu.dart';

// Complete expanded card content: discrete playback controls, capability-gated links and menu, source queue reinsert behavior and finite reveal.
class BravaisFocusBody extends StatefulWidget {
  const BravaisFocusBody({
    super.key,
    required this.slotKey,
    required this.item,
    required this.queued,
    required this.current,
    required this.titleWidth,
    required this.viewportWidth,
    required this.actions,
    required this.typography,
    required this.strings,
    required this.ink,
    required this.accent,
    required this.frames,
    required this.nowMs,
    required this.isPlaying,
    required this.entersLattice,
    required this.reducedMotion,
    this.glint,
  });
  final String slotKey;
  final BravaisItem item;
  final bool queued, current, entersLattice, reducedMotion;
  final double titleWidth, viewportWidth;
  final BravaisCardActions actions;
  final WallTypography typography;
  final FoliaStrings strings;
  final Color ink, accent;
  final Listenable frames;
  final double Function() nowMs;
  final ValueListenable<bool> isPlaying;
  final Widget? glint;
  @override
  State<BravaisFocusBody> createState() => _BravaisFocusBodyState();
}

class _BravaisFocusBodyState extends State<BravaisFocusBody> {
  late BravaisFocusReveal _reveal;
  bool _tickerEnabled = true;
  @override
  void initState() {
    super.initState();
    _createReveal();
  }

  void _createReveal() => _reveal = BravaisFocusReveal(
    frames: widget.frames,
    nowMs: widget.nowMs,
    startedAt: widget.nowMs(),
    reducedMotion: widget.reducedMotion,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _reveal.setActive(_tickerEnabled);
  }

  @override
  void didUpdateWidget(BravaisFocusBody old) {
    super.didUpdateWidget(old);
    if (!identical(old.frames, widget.frames)) {
      final elapsed = _reveal.nowMs() - _reveal.startedAt;
      _reveal.dispose();
      _reveal = BravaisFocusReveal(
        frames: widget.frames,
        nowMs: widget.nowMs,
        startedAt: widget.nowMs() - elapsed,
        reducedMotion: widget.reducedMotion,
      )..setActive(_tickerEnabled);
    } else {
      _reveal.nowMs = widget.nowMs;
      _reveal.setReduced(widget.reducedMotion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget,
        fontSize = w.viewportWidth <= 640
            ? 44.0
            : (w.viewportWidth * .06).clamp(48.0, 82.0),
        menu = w.actions.menuFor(w.item.key);
    return Stack(
      children: [
        Positioned(
          left: 32,
          right: 32,
          bottom: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WallTitle(
                title: w.item.title,
                targetWidth: (w.titleWidth - 64) * .76,
                style: w.typography.style(
                  fontSize,
                  color: w.ink,
                  weight: 700,
                  height: .95,
                  tracking: -.045,
                ),
                fontsEpoch: w.typography.fontsEpoch,
                locale: w.typography.locale,
                direction: w.typography.direction,
              ),
              const SizedBox(height: 12),
              _FocusLinks(
                slotKey: w.slotKey,
                item: w.item,
                actions: w.actions,
                typography: w.typography,
                ink: w.ink,
              ),
              const SizedBox(height: 31),
              if (w.current && w.actions.togglesCurrent)
                ValueListenableBuilder(
                  valueListenable: w.isPlaying,
                  builder: (_, playing, _) => _focusButtons(this, playing),
                )
              else
                _focusButtons(this, false),
            ],
          ),
        ),
        if (w.glint != null) w.glint!,
        if (menu.isNotEmpty)
          _FocusMenu(
            slotKey: w.slotKey,
            entries: menu,
            actions: w.actions,
            strings: w.strings,
            typography: w.typography,
            accent: w.accent,
          ),
      ],
    );
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }
}
