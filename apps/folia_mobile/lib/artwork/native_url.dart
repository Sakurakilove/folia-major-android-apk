import 'dart:convert';
import 'dart:ffi';

part 'native_url_bindings.dart';
part 'native_url_parameters.dart';

// Original URL()/URLSearchParams semantics run in a lazily loaded native parser; only cold artwork preparation calls FFI, never paint frames.
class NativeUrlLibrary {
  NativeUrlLibrary({DynamicLibrary? library})
    : _bindings = _UrlBindings(
        library ?? DynamicLibrary.open('libfolia_url.so'),
      );
  final _UrlBindings _bindings;
  String get version => _bindings.version;
  NativeUrl? parse(String value, {String? base}) {
    final p = _bindings.withUtf8(
      value,
      (bytes, length) => base == null
          ? _bindings.parse(bytes, length)
          : _bindings.withUtf8(
              base,
              (baseBytes, baseLength) =>
                  _bindings.parseWithBase(bytes, length, baseBytes, baseLength),
            ),
    );
    if (p == nullptr) return null;
    if (!_bindings.valid(p)) {
      _bindings.free(p);
      return null;
    }
    return NativeUrl._(this, p);
  }
}

class NativeUrl {
  NativeUrl._(this.library, this._pointer);
  final NativeUrlLibrary library;
  Pointer<Void> _pointer;
  _UrlBindings get _b => library._bindings;
  Pointer<Void> get _owner {
    if (_pointer == nullptr) throw StateError('Native URL owner is closed');
    return _pointer;
  }

  String _get(String property) => _b.read(_b.getters[property]!(_owner));
  String get href => _get('href');
  String get protocol => _get('protocol');
  String get hostname => _get('hostname');
  String get pathname => _get('pathname');
  String get search => _get('search');
  String get origin {
    final result = _b.origin(_owner);
    try {
      return _b.read(result);
    } finally {
      _b.freeOwned(result);
    }
  }

  set pathname(String value) {
    _b.withUtf8(value, (bytes, length) => _b.setPath(_owner, bytes, length));
  }

  T _params<T>(T Function(Pointer<Void>) use) {
    var params = _b.withUtf8(
      search,
      (bytes, length) => _b.parseParams(bytes, length),
    );
    if (params == nullptr) {
      throw StateError('Native URL parameters allocation failed');
    }
    try {
      params = _b.repair.normalize(params, _b);
      return use(params);
    } finally {
      _b.freeParams(params);
    }
  }

  String? parameter(String key) => _params(
    (params) => _b.withUtf8(key, (bytes, length) {
      if (!_b.hasParam(params, bytes, length)) return null;
      return _b.read(_b.getParam(params, bytes, length));
    }),
  );
  void setParameter(String key, String value) => _params((params) {
    _b.withUtf8(
      key,
      (k, kn) =>
          _b.withUtf8(value, (v, vn) => _b.setParam(params, k, kn, v, vn)),
    );
    final serialized = _b.serializeParams(params);
    try {
      _b.setSearch(_owner, serialized.data, serialized.length);
    } finally {
      _b.freeOwned(serialized);
    }
  });
  void dispose() {
    if (_pointer == nullptr) return;
    _b.free(_pointer);
    _pointer = nullptr;
  }
}
