import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'scene_first_frame.dart';
import 'scene_layers.dart';
import 'scene_transition.dart';

// Each layer owns compositor motion; children stay alive through exits and stay unfiltered at rest.
class SceneTransitionLayer<T> extends StatefulWidget {
  const SceneTransitionLayer({
    super.key,
    required this.layer,
    required this.transition,
    required this.onLeft,
    required this.onReady,
    required this.builder,
  });
  final SceneLayer<T> layer;
  final SceneTransition? transition;
  final ValueChanged<int> onLeft, onReady;
  final Widget Function(BuildContext context, T value) builder;
  @override
  State<SceneTransitionLayer<T>> createState() =>
      _SceneTransitionLayerState<T>();
}

class _SceneTransitionLayerState<T> extends State<SceneTransitionLayer<T>>
    with TickerProviderStateMixin {
  late final SceneTransitionTrack? _enterTrack = widget.layer.comesIn
      ? widget.transition?.enter
      : null;
  late final _enter = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: _enterTrack == null
          ? 1
          : _enterTrack.delayMs + _enterTrack.durationMs,
    ),
  );
  late final _leave = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          mounted &&
          widget.layer.leaving) {
        widget.onLeft(widget.layer.key);
      }
    });
  late final _clocks = Listenable.merge([_enter, _leave]);
  late final _report = SceneFirstFrameReport(_ready);
  ({double opacity, double blur, double scale})? _leaveFrom;
  bool _leaving = false;
  bool _queuedReady = false;
  @override
  void initState() {
    super.initState();
    if (_enterTrack != null && !widget.layer.waits) _enter.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_report.claimed) _report.drawn();
    });
    _sync();
  }

  void _ready() {
    void deliver() {
      if (mounted && !widget.layer.leaving) widget.onReady(widget.layer.key);
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.postFrameCallbacks) {
      deliver();
      return;
    }
    if (_queuedReady) return;
    _queuedReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queuedReady = false;
      deliver();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didUpdateWidget(SceneTransitionLayer<T> old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (!widget.layer.waits && widget.layer.leaving && !_leaving) {
      _leaving = true;
      final track = widget.transition?.leave;
      if (track == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onLeft(widget.layer.key);
        });
      } else {
        _leaveFrom = _pose();
        _enter.stop();
        _leave.duration = Duration(
          milliseconds: track.delayMs + track.durationMs,
        );
        _leave.forward(from: 0);
      }
    } else if (!_leaving && _enterTrack != null) {
      if (widget.layer.waits && !widget.layer.leaving) {
        _enter.stop();
      } else if (!_enter.isCompleted && !_enter.isAnimating) {
        _enter.forward();
      }
    }
  }

  ({double opacity, double blur, double scale}) _pose() {
    if (_leaveFrom != null) {
      final from = _leaveFrom!,
          track = widget.transition!.leave,
          progress = track.progress(
            _leave.value * _leave.duration!.inMilliseconds,
          );
      return (
        opacity: from.opacity + (track.opacity - from.opacity) * progress,
        blur: from.blur + (track.blur - from.blur) * progress,
        scale: from.scale + (track.scale - from.scale) * progress,
      );
    }
    final track = _enterTrack;
    if (track == null) return (opacity: 1, blur: 0, scale: 1);
    final remaining =
        1 - track.progress(_enter.value * _enter.duration!.inMilliseconds);
    return (
      opacity: 1 + (track.opacity - 1) * remaining,
      blur: track.blur * remaining,
      scale: 1 + (track.scale - 1) * remaining,
    );
  }

  @override
  void dispose() {
    _report.close();
    _enter.dispose();
    _leave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: widget.layer.leaving,
    child: ExcludeSemantics(
      excluding: widget.layer.leaving,
      child: AnimatedBuilder(
        animation: _clocks,
        child: SceneFirstFrameScope(
          report: _report,
          child: Builder(
            builder: (context) => widget.builder(context, widget.layer.value),
          ),
        ),
        builder: (context, child) {
          final pose = _pose();
          return Opacity(
            opacity: pose.opacity.clamp(0, 1),
            child: ImageFiltered(
              enabled: pose.blur > 0,
              imageFilter: ui.ImageFilter.blur(
                sigmaX: pose.blur,
                sigmaY: pose.blur,
              ),
              child: Transform.scale(scale: pose.scale, child: child),
            ),
          );
        },
      ),
    ),
  );
}
