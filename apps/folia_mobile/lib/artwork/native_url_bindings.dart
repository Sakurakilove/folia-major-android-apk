part of 'native_url.dart';

// Struct views are borrowed until the owning URL/parameter mutates; owned upstream strings and temporary UTF-8 buffers are released separately.
final class _AdaString extends Struct {
  external Pointer<Uint8> data;
  @UintPtr()
  external int length;
}

typedef _GetNative = _AdaString Function(Pointer<Void>);
typedef _GetDart = _AdaString Function(Pointer<Void>);

class _UrlBindings {
  _UrlBindings(DynamicLibrary lib) {
    repair = _UrlParameterRepair(lib);
    if (lib.lookupFunction<Uint32 Function(), int Function()>(
          'folia_url_abi_version',
        )() !=
        1) {
      throw StateError('Incompatible native URL ABI');
    }
    allocate = lib
        .lookupFunction<
          Pointer<Void> Function(UintPtr),
          Pointer<Void> Function(int)
        >('folia_url_allocate');
    release = lib
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('folia_url_release');
    final versionPointer = lib
        .lookupFunction<Pointer<Uint8> Function(), Pointer<Uint8> Function()>(
          'ada_get_version',
        )();
    var size = 0;
    while (size < 64 && versionPointer[size] != 0) {
      size++;
    }
    version = utf8.decode(versionPointer.asTypedList(size));
    if (version != '3.4.4') {
      throw StateError('Unexpected native URL parser version');
    }
    parse = lib
        .lookupFunction<
          Pointer<Void> Function(Pointer<Uint8>, UintPtr),
          Pointer<Void> Function(Pointer<Uint8>, int)
        >('ada_parse');
    parseWithBase = lib
        .lookupFunction<
          Pointer<Void> Function(
            Pointer<Uint8>,
            UintPtr,
            Pointer<Uint8>,
            UintPtr,
          ),
          Pointer<Void> Function(Pointer<Uint8>, int, Pointer<Uint8>, int)
        >('ada_parse_with_base');
    valid = lib
        .lookupFunction<
          Bool Function(Pointer<Void>),
          bool Function(Pointer<Void>)
        >('ada_is_valid');
    free = lib
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('ada_free');
    getters = {
      for (final key in ['href', 'protocol', 'hostname', 'pathname', 'search'])
        key: lib.lookupFunction<_GetNative, _GetDart>('ada_get_$key'),
    };
    origin = lib.lookupFunction<_GetNative, _GetDart>('ada_get_origin');
    freeOwned = lib
        .lookupFunction<Void Function(_AdaString), void Function(_AdaString)>(
          'ada_free_owned_string',
        );
    setPath = lib
        .lookupFunction<
          Bool Function(Pointer<Void>, Pointer<Uint8>, UintPtr),
          bool Function(Pointer<Void>, Pointer<Uint8>, int)
        >('ada_set_pathname');
    setSearch = lib
        .lookupFunction<
          Void Function(Pointer<Void>, Pointer<Uint8>, UintPtr),
          void Function(Pointer<Void>, Pointer<Uint8>, int)
        >('ada_set_search');
    parseParams = lib
        .lookupFunction<
          Pointer<Void> Function(Pointer<Uint8>, UintPtr),
          Pointer<Void> Function(Pointer<Uint8>, int)
        >('ada_parse_search_params');
    freeParams = lib
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('ada_free_search_params');
    hasParam = lib
        .lookupFunction<
          Bool Function(Pointer<Void>, Pointer<Uint8>, UintPtr),
          bool Function(Pointer<Void>, Pointer<Uint8>, int)
        >('ada_search_params_has');
    getParam = lib
        .lookupFunction<
          _AdaString Function(Pointer<Void>, Pointer<Uint8>, UintPtr),
          _AdaString Function(Pointer<Void>, Pointer<Uint8>, int)
        >('ada_search_params_get');
    setParam = lib
        .lookupFunction<
          Void Function(
            Pointer<Void>,
            Pointer<Uint8>,
            UintPtr,
            Pointer<Uint8>,
            UintPtr,
          ),
          void Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Uint8>, int)
        >('ada_search_params_set');
    serializeParams = lib.lookupFunction<_GetNative, _GetDart>(
      'ada_search_params_to_string',
    );
  }
  late final String version;
  late final _UrlParameterRepair repair;
  late final Pointer<Void> Function(int) allocate;
  late final void Function(Pointer<Void>) release, free, freeParams;
  late final Pointer<Void> Function(Pointer<Uint8>, int) parse, parseParams;
  late final Pointer<Void> Function(Pointer<Uint8>, int, Pointer<Uint8>, int)
  parseWithBase;
  late final bool Function(Pointer<Void>) valid;
  late final Map<String, _GetDart> getters;
  late final _GetDart origin, serializeParams;
  late final void Function(_AdaString) freeOwned;
  late final bool Function(Pointer<Void>, Pointer<Uint8>, int) setPath,
      hasParam;
  late final void Function(Pointer<Void>, Pointer<Uint8>, int) setSearch;
  late final _AdaString Function(Pointer<Void>, Pointer<Uint8>, int) getParam;
  late final void Function(
    Pointer<Void>,
    Pointer<Uint8>,
    int,
    Pointer<Uint8>,
    int,
  )
  setParam;
  T withUtf8<T>(String text, T Function(Pointer<Uint8>, int) use) {
    final bytes = utf8.encode(text),
        buffer = allocate(bytes.length + 1).cast<Uint8>();
    if (buffer == nullptr) throw OutOfMemoryError();
    final view = buffer.asTypedList(bytes.length + 1);
    view.setRange(0, bytes.length, bytes);
    view[bytes.length] = 0;
    try {
      return use(buffer, bytes.length);
    } finally {
      release(buffer.cast<Void>());
    }
  }

  String read(_AdaString value) => value.length == 0
      ? ''
      : utf8.decode(value.data.asTypedList(value.length), allowMalformed: true);
}
