import 'dart:ffi';
import 'dart:convert';
import 'dart:typed_data';

// Ticket claim and native finalization keep descriptor ownership independent from Android Activity lifetime and asynchronous engine buffer reads.
class NativeArtworkDescriptors {
  NativeArtworkDescriptors({DynamicLibrary? library}) {
    final native = library ?? DynamicLibrary.open('libfolia_artwork.so');
    if (native.lookupFunction<Uint32 Function(), int Function()>(
          'folia_artwork_abi_version',
        )() !=
        1) {
      throw StateError('Incompatible native artwork descriptor ABI');
    }
    _claim = native
        .lookupFunction<
          Pointer<Void> Function(Uint64),
          Pointer<Void> Function(int)
        >('folia_artwork_claim');
    _fd = native
        .lookupFunction<
          Int32 Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >('folia_artwork_lease_fd');
    _releaseTicket = native
        .lookupFunction<Void Function(Uint64), void Function(int)>(
          'folia_artwork_release_ticket',
        );
    final close = native.lookup<NativeFunction<Void Function(Pointer<Void>)>>(
      'folia_artwork_close_lease',
    );
    _close = close.asFunction();
    _finalizer = NativeFinalizer(close);
    _allocate = native
        .lookupFunction<
          Pointer<Void> Function(UintPtr),
          Pointer<Void> Function(int)
        >('folia_artwork_allocate');
    _release = native
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('folia_artwork_release');
    _decodeData = native
        .lookupFunction<
          Pointer<Void> Function(Pointer<Uint8>, UintPtr),
          Pointer<Void> Function(Pointer<Uint8>, int)
        >('folia_artwork_decode_data');
    _dataBytes = native
        .lookupFunction<
          Pointer<Uint8> Function(Pointer<Void>),
          Pointer<Uint8> Function(Pointer<Void>)
        >('folia_artwork_data_bytes');
    _dataSize = native
        .lookupFunction<
          UintPtr Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >('folia_artwork_data_size');
    final closeData = native
        .lookup<NativeFunction<Void Function(Pointer<Void>)>>(
          'folia_artwork_close_data',
        );
    _closeData = closeData.asFunction();
    _dataFinalizer = NativeFinalizer(closeData);
  }
  late final Pointer<Void> Function(int) _claim;
  late final int Function(Pointer<Void>) _fd;
  late final void Function(int) _releaseTicket;
  late final void Function(Pointer<Void>) _close;
  late final NativeFinalizer _finalizer;
  late final Pointer<Void> Function(int) _allocate;
  late final void Function(Pointer<Void>) _release, _closeData;
  late final Pointer<Void> Function(Pointer<Uint8>, int) _decodeData;
  late final Pointer<Uint8> Function(Pointer<Void>) _dataBytes;
  late final int Function(Pointer<Void>) _dataSize;
  late final NativeFinalizer _dataFinalizer;
  NativeArtworkData decodeDataUri(String normalized) {
    final bytes = utf8.encode(normalized),
        input = _allocate(bytes.length + 1).cast<Uint8>();
    if (input == nullptr) throw OutOfMemoryError();
    final view = input.asTypedList(bytes.length + 1);
    view.setRange(0, bytes.length, bytes);
    view[bytes.length] = 0;
    final Pointer<Void> result;
    try {
      result = _decodeData(input, bytes.length);
    } finally {
      _release(input.cast());
    }
    if (result == nullptr) throw StateError('Invalid inline artwork');
    return NativeArtworkData._(this, result);
  }

  NativeArtworkLease? claim(int ticket) {
    final pointer = _claim(ticket);
    if (pointer == nullptr) {
      _releaseTicket(ticket);
      return null;
    }
    return NativeArtworkLease._(this, pointer);
  }
}

class NativeArtworkData implements Finalizable {
  NativeArtworkData._(this._library, this._pointer) {
    _library._dataFinalizer.attach(
      this,
      _pointer,
      detach: this,
      externalSize: _library._dataSize(_pointer),
    );
  }
  final NativeArtworkDescriptors _library;
  Pointer<Void> _pointer;
  // Borrowed native bytes remain valid only until dispose; the engine's ImmutableBuffer copies them before its future completes.
  Uint8List get bytes {
    if (_pointer == nullptr) {
      throw StateError('Inline artwork buffer is closed');
    }
    final size = _library._dataSize(_pointer);
    return size == 0
        ? Uint8List(0)
        : _library._dataBytes(_pointer).asTypedList(size);
  }

  void dispose() {
    if (_pointer == nullptr) return;
    _library._dataFinalizer.detach(this);
    _library._closeData(_pointer);
    _pointer = nullptr;
  }
}

class NativeArtworkLease implements Finalizable {
  NativeArtworkLease._(this._library, this._pointer) {
    _library._finalizer.attach(this, _pointer, detach: this, externalSize: 64);
  }
  final NativeArtworkDescriptors _library;
  Pointer<Void> _pointer;
  int get fd {
    if (_pointer == nullptr) {
      throw StateError('Artwork descriptor lease is closed');
    }
    return _library._fd(_pointer);
  }

  void dispose() {
    if (_pointer == nullptr) return;
    _library._finalizer.detach(this);
    _library._close(_pointer);
    _pointer = nullptr;
  }
}
