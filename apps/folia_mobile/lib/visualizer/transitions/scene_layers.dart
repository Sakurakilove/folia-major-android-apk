// Pure layerTransition.ts state: keep the visible predecessor through first-frame waits and finish rapid handovers in order.
class SceneLayer<T> {
  const SceneLayer({
    required this.key,
    required this.value,
    required this.leaving,
    required this.comesIn,
    required this.waits,
  });
  final int key;
  final T value;
  final bool leaving, comesIn, waits;
  SceneLayer<T> copy({bool? leaving, bool? waits}) => SceneLayer(
    key: key,
    value: value,
    leaving: leaving ?? this.leaving,
    comesIn: comesIn,
    waits: waits ?? this.waits,
  );
  Map<String, dynamic> toJson() => {
    'key': key,
    'value': value,
    'leaving': leaving,
    'comesIn': comesIn,
    'waits': waits,
  };
}

List<SceneLayer<T>> _started<T>(List<SceneLayer<T>> layers) => [
  for (final layer in layers) layer.copy(waits: false),
];

List<SceneLayer<T>> nextShownLayers<T>(
  List<SceneLayer<T>> layers,
  T value,
  bool animate,
  bool waits,
) {
  final current = layers.last;
  if (current.value == value) {
    if (!animate) {
      return layers.length == 1 && !current.waits
          ? layers
          : [current.copy(waits: false)];
    }
    return current.waits && !waits ? _started(layers) : layers;
  }
  final next = SceneLayer(
    key: current.key + 1,
    value: value,
    leaving: false,
    comesIn: animate,
    waits: animate && waits,
  );
  if (!animate) return [next];
  if (!current.waits && layers.length > 1 && layers.first.leaving) {
    return layers;
  }
  if (!current.waits) {
    return [current.copy(leaving: true, waits: next.waits), next];
  }
  final onScreen = layers.length > 1 ? layers[layers.length - 2] : null;
  if (onScreen == null) return [next];
  if (onScreen.value == value) {
    return [onScreen.copy(leaving: false, waits: false)];
  }
  return [onScreen.copy(waits: next.waits), next];
}

List<SceneLayer<T>> startedLayers<T>(List<SceneLayer<T>> layers, int key) =>
    layers.last.key == key && layers.last.waits ? _started(layers) : layers;
