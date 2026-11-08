import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../visualizer/scene_frame_clock.dart';

import '../../wall/input/wall_input_region.dart';
import '../../wall/input/wall_pointer_pan.dart';
import '../../wall/wall_slots.dart';
import '../../wall/wall_types.dart';
import '../bravais_camera.dart';
import '../bravais_plate_painter.dart';
import '../bravais_reflow.dart';
import '../display/bravais_display.dart';
import '../display/bravais_display_slots.dart';
import '../shape/bravais_shape_cache.dart';
import '../shape/bravais_shape_collect.dart';
import '../shape/bravais_wall_shape.dart';
import '../tiles/bravais_card_palette.dart';
import '../tiles/bravais_item.dart';
import '../tiles/bravais_tile_input.dart';
import '../tiles/focus/bravais_focus_actions.dart';
import '../tiles/skin/bravais_card_resources.dart';
import 'bravais_plate_cache.dart';
import 'bravais_retained_slots.dart';
import 'bravais_wall_selection.dart';
import 'bravais_wall_view.dart';

part 'bravais_wall_scene_state.dart';

// The wall plane's real native host. The full stage still supplies its original ground/seam/chrome/navigation; this component does not substitute another product shell.
class BravaisWallScene extends StatefulWidget {
  const BravaisWallScene({
    super.key,
    required this.camera,
    required this.display,
    required this.selection,
    required this.resources,
    required this.actions,
    required this.noteAlbumSource,
    required this.palette,
    required this.dpr,
    required this.committedScale,
    this.backdropOpen = false,
    this.lightsOut = false,
    this.tinted = false,
    this.stackEdges = true,
    this.posterWall = false,
    this.posterTint = const Color(0x00000000),
    this.reducedMotion = false,
    this.reducedTransitions = false,
    this.managingHidden = false,
    this.entersLattice = false,
    this.active = true,
    this.interactive = true,
    this.android = true,
    this.focusReflow,
  });
  final BravaisCamera camera;
  final ValueListenable<BravaisDisplay?> display;
  final ValueListenable<BravaisWallSelection> selection;
  final BravaisCardResources resources;
  final BravaisCardActions actions;
  final void Function(BuildContext tile, BravaisItem item) noteAlbumSource;
  final BravaisCardPalette palette;
  final bool posterWall;
  final Color posterTint;
  final Map<String, WallSlot> Function(
    String? expanded,
    BravaisWallShape shape,
  )?
  focusReflow;
  final double dpr, committedScale;
  final bool backdropOpen,
      lightsOut,
      tinted,
      stackEdges,
      reducedMotion,
      reducedTransitions,
      managingHidden,
      entersLattice,
      active,
      interactive,
      android;
  @override
  State<BravaisWallScene> createState() => _BravaisWallSceneState();
}

class _BravaisWallSceneState extends State<BravaisWallScene>
    with WidgetsBindingObserver {
  final _pointerHistory = BravaisPointerHistory(),
      _plateCache = BravaisPlateCache();
  late final BravaisReflow _reflow;
  late final BravaisPlatePainter _platePainter;
  late SceneFrameDomain _clockDomain;
  late BravaisCardResources _cardResources;
  List<WallSlot> _slots = const [];
  WallBounds? _lastBounds;
  BravaisWallShape? _lastShape;
  BravaisPlateSet? _lastPlates;
  Color? _lastPaper;
  String? _expanded;
  BravaisWallShape? _reflowShape;
  Map<String, WallRect> _targetReflow = const {};
  bool _foreground = true, _tickerEnabled = true;
  bool get _active => widget.active && _foreground && _tickerEnabled;
  double _now() => widget.resources.nowMs();
  WallRect? _resting(String key) {
    final slot = shapeSlotFromKey(
      widget.display.value?.shape ?? bravaisBlockShape,
      key,
    );
    return slot == null
        ? null
        : WallRect(slot.x, slot.y, slot.width, slot.height);
  }

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _pointerHistory.attach();
    _clockDomain = SceneFrameDomain(widget.resources.frames, _active);
    _cardResources = widget.resources.withFrames(_clockDomain);
    _reflow = BravaisReflow(
      frames: _clockDomain,
      nowMs: _now,
      resting: _resting,
    );
    _platePainter = BravaisPlatePainter(color: widget.palette.background);
    _listen(widget, true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _syncActive();
  }

  @override
  void didUpdateWidget(BravaisWallScene old) {
    super.didUpdateWidget(old);
    _listen(old, false);
    _listen(widget, true);
    if (!identical(old.camera, widget.camera)) old.camera.setActive(false);
    if (!identical(old.resources.frames, widget.resources.frames)) {
      _clockDomain.dispose();
      _clockDomain = SceneFrameDomain(widget.resources.frames, _active);
      _reflow.rebindFrames(_clockDomain);
    }
    _cardResources = widget.resources.withFrames(_clockDomain);
    if (old.reducedMotion != widget.reducedMotion) _reflowShape = null;
    if (old.focusReflow != widget.focusReflow) _reflowShape = null;
    _syncActive();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncActive();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _buildPlane();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listen(widget, false);
    widget.camera.setActive(false);
    _pointerHistory.dispose();
    _plateCache.dispose();
    _reflow.dispose();
    _platePainter.dispose();
    _clockDomain.dispose();
    super.dispose();
  }
}
