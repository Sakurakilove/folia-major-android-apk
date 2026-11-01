import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../i18n/folia_strings.dart';
import '../../rendering/css_shadows.dart';
import '../../rendering/folia_icons.dart';
import 'monet_portrait_drift.dart';
import 'monet_portrait_frame.dart';
import 'monet_portrait_drag_region.dart';
import 'monet_portrait_hanger.dart';
import 'monet_tuning.dart';

// A saved offset changes header reservation only on commit; live dragging stays local and never crosses a platform channel.
class MonetPortrait extends StatefulWidget {
  const MonetPortrait({
    super.key,
    required this.baseWidth,
    required this.tuning,
    required this.primary,
    required this.accent,
    required this.background,
    required this.chaotic,
    required this.strings,
    this.image,
    this.source,
    this.onTuningChange,
  });
  final double baseWidth;
  final MonetTuning tuning;
  final Color primary, accent, background;
  final bool chaotic;
  final FoliaStrings strings;
  final ImageProvider? image;
  final String? source;
  final ValueChanged<MonetTuning>? onTuningChange;
  @override
  State<MonetPortrait> createState() => _MonetPortraitState();
}

class _MonetPortraitState extends State<MonetPortrait> {
  late final _offset = ValueNotifier(widget.tuning.portraitOffsetX);
  bool _editing = false, _dragging = false;
  int? _pointer;
  double? _downX;
  double _startX = 0;
  Timer? _dragReset;
  @override
  void didUpdateWidget(MonetPortrait old) {
    super.didUpdateWidget(old);
    if (old.tuning.portraitOffsetX != widget.tuning.portraitOffsetX) {
      _offset.value = widget.tuning.portraitOffsetX;
    }
  }

  void _tap() {
    if (_dragging) return;
    if (_editing) {
      // JS Math.round ties toward +infinity, unlike Dart round for negative halves.
      widget.onTuningChange?.call(
        widget.tuning.withPortraitOffset((_offset.value + .5).floorToDouble()),
      );
    }
    setState(() {
      _editing = !_editing;
    });
  }

  void _down(PointerDownEvent event) {
    if (!_editing || _pointer != null) return;
    _dragReset?.cancel();
    _dragging = false;
    _pointer = event.pointer;
    _downX = event.position.dx;
    _startX = _offset.value;
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer || _downX == null) return;
    final dx = event.position.dx - _downX!;
    if (!_dragging && dx.abs() < 3) return;
    _dragging = true;
    _offset.value = (_startX + dx).clamp(-150, 0);
  }

  void _end(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _downX = null;
    _dragReset = Timer(const Duration(milliseconds: 50), () {
      _dragging = false;
    });
  }

  @override
  void dispose() {
    _dragReset?.cancel();
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final square = widget.tuning.portraitStyle == 'square',
        width = widget.baseWidth * (square ? 1.35135 : 1),
        bleed = square ? widget.baseWidth * .35135 : 0.0,
        height = width / (square ? 1 : .74);
    return SizedBox(
      width: widget.baseWidth,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -bleed,
            top: 0,
            width: width,
            height: height,
            child: ValueListenableBuilder(
              valueListenable: _offset,
              child: MonetPortraitDrift(
                chaotic: widget.chaotic,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: MonetPortraitFrame(
                        square: square,
                        primary: widget.primary,
                        accent: widget.accent,
                        background: widget.background,
                        image: widget.image,
                        source: widget.source,
                      ),
                    ),
                    if (widget.tuning.showPortraitDragHanger)
                      Positioned(
                        top: -12,
                        right: 32,
                        child: MonetPortraitHanger(
                          editing: _editing,
                          primary: widget.primary,
                          accent: widget.accent,
                          background: widget.background,
                          onTap: _tap,
                          onDown: _down,
                          onMove: _move,
                          onEnd: _end,
                        ),
                      ),
                  ],
                ),
              ),
              builder: (context, value, child) =>
                  Transform.translate(offset: Offset(value, 0), child: child),
            ),
          ),
          if (_editing)
            Positioned(
              left: -bleed - 150,
              right: 0,
              top: -12,
              bottom: -12,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: MonetPortraitDragRegion(
                    widget.primary.withValues(alpha: .24),
                  ),
                ),
              ),
            ),
          if (_editing)
            Positioned(
              right: 0,
              top: -52,
              child: GestureDetector(
                onTap: () {
                  _offset.value = 0;
                },
                child: Semantics(
                  button: true,
                  label: widget.strings.t('common.reset'),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        cssBoxShadow(
                          const Color(0x1f000000),
                          const Offset(0, 4),
                          12,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.background.withValues(alpha: .86),
                            border: Border.all(
                              color: widget.primary.withValues(alpha: .16),
                            ),
                          ),
                          child: FoliaIcon(
                            'RotateCcw',
                            color: widget.primary,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
