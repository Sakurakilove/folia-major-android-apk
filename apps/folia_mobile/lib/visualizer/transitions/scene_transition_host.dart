import 'package:flutter/widgets.dart';

import 'scene_transition.dart';
import 'scene_transition_controller.dart';
import 'scene_transition_layer.dart';

// Shared host for every style/background. The caller coordinates simultaneous first-frame releases when both change together.
class SceneTransitionHost<T> extends StatelessWidget {
  const SceneTransitionHost({
    super.key,
    required this.controller,
    required this.builder,
    required this.transition,
    this.onReady,
    this.background = false,
  });
  final SceneTransitionController<T> controller;
  final Widget Function(BuildContext context, T value) builder;
  final SceneTransition? transition;
  final ValueChanged<int>? onReady;
  final bool background;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Stack(
      fit: StackFit.expand,
      children: [
        for (final layer in controller.layers)
          SceneTransitionLayer(
            key: ValueKey(layer.key),
            layer: layer,
            builder: builder,
            transition: background ? transition?.underNext() : transition,
            onLeft: controller.left,
            onReady: onReady ?? controller.firstFrame,
          ),
      ],
    ),
  );
}
