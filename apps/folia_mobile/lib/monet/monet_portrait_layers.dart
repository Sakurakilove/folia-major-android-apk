// Port of monetPortraitCrossfade.ts: rapid skips retain decoded lower layers until an opaque cover settles.
class MonetPortraitLayer {
  const MonetPortraitLayer(this.key, this.src);
  final String key, src;
  Map<String, dynamic> toJson() => {'key': key, 'src': src};
}

const monetPortraitFadeMs = 900;
const monetPortraitMaxLayers = 4;
String? monetPortraitTargetSource(List<MonetPortraitLayer> layers) =>
    layers.lastOrNull?.src;

List<MonetPortraitLayer> pushMonetPortraitLayer(
  List<MonetPortraitLayer> layers,
  String src,
  String key,
) {
  if (monetPortraitTargetSource(layers) == src) return layers;
  final next = [...layers, MonetPortraitLayer(key, src)];
  return next.length > monetPortraitMaxLayers
      ? next.sublist(next.length - monetPortraitMaxLayers)
      : next;
}

List<MonetPortraitLayer> settleMonetPortraitLayers(
  List<MonetPortraitLayer> layers,
  String key,
) {
  final index = layers.indexWhere((layer) => layer.key == key);
  return index <= 0 ? layers : layers.sublist(index);
}
