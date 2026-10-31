import 'package:flutter/foundation.dart';

// Public invalidation boundary for caches and cameras; it carries no frame-valued widget state.
class RepaintSignal extends ChangeNotifier {
  void invalidate() => notifyListeners();
}
