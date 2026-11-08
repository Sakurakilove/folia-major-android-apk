import 'package:flutter/foundation.dart';

// App-owned registrations survive the stage's delayed unmount. Layer identity is reference identity; old surfaces release only their own token during overlapping entry/exit.
enum BravaisLayerSlot { home, top }

typedef BravaisPendingOrigin = ({String fromLayerKey, String? slotKey});

class BravaisLayerRegistration<T extends Object> {
  const BravaisLayerRegistration(this.token, this.layer);
  final int token;
  final T layer;
}

class BravaisStageState<T extends Object> {
  const BravaisStageState({this.home, this.top, this.pendingOrigin});
  final BravaisLayerRegistration<T>? home, top;
  final BravaisPendingOrigin? pendingOrigin;
}

BravaisStageState<T> applyBravaisLayerRegistration<T extends Object>(
  BravaisStageState<T> state,
  BravaisLayerSlot slot,
  int token,
  T layer,
) {
  final current = slot == BravaisLayerSlot.home ? state.home : state.top;
  if (current?.token == token && identical(current?.layer, layer)) return state;
  final registration = BravaisLayerRegistration(token, layer);
  return BravaisStageState(
    home: slot == BravaisLayerSlot.home ? registration : state.home,
    top: slot == BravaisLayerSlot.top ? registration : state.top,
    pendingOrigin: state.pendingOrigin,
  );
}

BravaisStageState<T> releaseBravaisLayerRegistration<T extends Object>(
  BravaisStageState<T> state,
  BravaisLayerSlot slot,
  int token,
) {
  if ((slot == BravaisLayerSlot.home ? state.home : state.top)?.token !=
      token) {
    return state;
  }
  return BravaisStageState(
    home: slot == BravaisLayerSlot.home ? null : state.home,
    top: slot == BravaisLayerSlot.top ? null : state.top,
    pendingOrigin: state.pendingOrigin,
  );
}

({T? layer, bool owned}) resolveCurrentBravaisLayer<T extends Object>({
  required num depth,
  required BravaisLayerRegistration<T>? home,
  required BravaisLayerRegistration<T>? top,
  required T? previous,
}) {
  if (depth <= 0) return (layer: home?.layer ?? previous, owned: home != null);
  if (top != null) return (layer: top.layer, owned: true);
  return (layer: previous, owned: false);
}

class BravaisStageStore<T extends Object>
    extends ValueNotifier<BravaisStageState<T>> {
  BravaisStageStore() : super(BravaisStageState<T>());
  int _nextToken = 1;
  int takeToken() => _nextToken++;
  void register(BravaisLayerSlot slot, int token, T layer) =>
      value = applyBravaisLayerRegistration(value, slot, token, layer);
  void release(BravaisLayerSlot slot, int token) =>
      value = releaseBravaisLayerRegistration(value, slot, token);
  void setPendingOrigin(BravaisPendingOrigin? origin) =>
      value = BravaisStageState(
        home: value.home,
        top: value.top,
        pendingOrigin: origin,
      );
  BravaisPendingOrigin? takePendingOrigin(String? fromLayerKey) {
    final origin = value.pendingOrigin;
    if (origin == null) return null;
    setPendingOrigin(null);
    return origin.fromLayerKey == fromLayerKey ? origin : null;
  }
}
