import 'package:flutter/widgets.dart';

// A renderer claims readiness before expensive setup and reports after its real content is painted; no captured picture substitutes.
class SceneFirstFrameReport {
  SceneFirstFrameReport(this._onDrawn);
  final VoidCallback _onDrawn;
  bool claimed = false, _drawn = false, _closed = false;
  void claim() {
    if (!_closed) claimed = true;
  }

  void drawn() {
    if (_closed || _drawn) return;
    _drawn = true;
    _onDrawn();
  }

  void close() {
    _closed = true;
  }
}

class SceneFirstFrameScope extends InheritedWidget {
  const SceneFirstFrameScope({
    super.key,
    required this.report,
    required super.child,
  });
  final SceneFirstFrameReport report;
  static SceneFirstFrameReport? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SceneFirstFrameScope>()
      ?.report;
  @override
  bool updateShouldNotify(SceneFirstFrameScope old) => old.report != report;
}
