part of 'native_url.dart';

// Ada retains decoded raw bytes in query pairs; JavaScript URLSearchParams replaces malformed UTF-8 with U+FFFD before comparing or serializing them.
final class _AdaPair extends Struct {
  external _AdaString key;
  external _AdaString value;
}

class _UrlParameterRepair {
  _UrlParameterRepair(DynamicLibrary lib) {
    entries = lib
        .lookupFunction<
          Pointer<Void> Function(Pointer<Void>),
          Pointer<Void> Function(Pointer<Void>)
        >('ada_search_params_get_entries');
    hasNext = lib
        .lookupFunction<
          Bool Function(Pointer<Void>),
          bool Function(Pointer<Void>)
        >('ada_search_params_entries_iter_has_next');
    next = lib
        .lookupFunction<
          _AdaPair Function(Pointer<Void>),
          _AdaPair Function(Pointer<Void>)
        >('ada_search_params_entries_iter_next');
    freeEntries = lib
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('ada_free_search_params_entries_iter');
    append = lib
        .lookupFunction<
          Void Function(
            Pointer<Void>,
            Pointer<Uint8>,
            UintPtr,
            Pointer<Uint8>,
            UintPtr,
          ),
          void Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Uint8>, int)
        >('ada_search_params_append');
  }
  late final Pointer<Void> Function(Pointer<Void>) entries;
  late final bool Function(Pointer<Void>) hasNext;
  late final _AdaPair Function(Pointer<Void>) next;
  late final void Function(Pointer<Void>) freeEntries;
  late final void Function(
    Pointer<Void>,
    Pointer<Uint8>,
    int,
    Pointer<Uint8>,
    int,
  )
  append;
  Pointer<Void> normalize(Pointer<Void> params, _UrlBindings b) {
    final iterator = entries(params), pairs = <(String, String)>[];
    var malformed = false;
    String decode(_AdaString value) {
      try {
        return utf8.decode(value.data.asTypedList(value.length));
      } on FormatException {
        malformed = true;
        return b.read(value);
      }
    }

    try {
      while (hasNext(iterator)) {
        final pair = next(iterator);
        pairs.add((decode(pair.key), decode(pair.value)));
      }
    } finally {
      freeEntries(iterator);
    }
    if (!malformed) return params;
    final repaired = b.withUtf8('', (p, n) => b.parseParams(p, n));
    if (repaired == nullptr) {
      throw StateError('Native URL parameters allocation failed');
    }
    try {
      for (final pair in pairs) {
        b.withUtf8(
          pair.$1,
          (k, kn) =>
              b.withUtf8(pair.$2, (v, vn) => append(repaired, k, kn, v, vn)),
        );
      }
    } catch (_) {
      b.freeParams(repaired);
      rethrow;
    }
    b.freeParams(params);
    return repaired;
  }
}
