import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

// A native image effect shares its owner's finite scene clock. Image frames remain native handles and never become per-frame widget/channel payloads.
abstract class WallArtworkEffect extends ChangeNotifier {
  bool get needsImage => true;
  void imageChanged(ui.Image? image) {}
  void underlayChanged(ui.Image? image) {}
  void paint(ui.Canvas canvas, ui.Offset offset, ui.Size size, ui.Image? image);
}
