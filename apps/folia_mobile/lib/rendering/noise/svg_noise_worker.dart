part of 'native_svg_noise.dart';

// A top-level primitive-only job avoids capturing a UI owner or an unsendable DynamicLibrary. Ownership remains native until the receiving isolate adopts the address.
Future<(int, int, int, int)> _runNoise((String, int, double, double) request) =>
    Isolate.run(() => _generateNoise(request));

(int, int, int, int) _generateNoise((String, int, double, double) request) {
  final bindings = _SvgNoiseBindings(request.$1),
      pointer = bindings.create(request.$2, request.$3, request.$4);
  if (pointer == nullptr) {
    throw StateError('Cannot create full-resolution SVG noise texture');
  }
  try {
    return (
      pointer.address,
      bindings.width(pointer),
      bindings.height(pointer),
      bindings.size(pointer),
    );
  } catch (_) {
    bindings.close(pointer);
    rethrow;
  }
}
