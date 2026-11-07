import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

part 'svg_noise_worker.dart';

// Static SVG pixels are generated once off the UI isolate, at the actual image size and DPR. Only a native ownership address returns; there is no bitmap channel or frame polling.
enum SvgNoiseRecipe { wall, poster, paper }

class NativeSvgNoise {
  NativeSvgNoise({String? libraryPath})
    : path =
          libraryPath ??
          Platform.environment['FOLIA_RENDERING_LIBRARY'] ??
          'libfolia_rendering.so';
  final String path;
  _SvgNoiseBindings? _bindings;
  Future<SvgNoisePixels> create(
    SvgNoiseRecipe recipe, {
    required double cssExtent,
    required double dpr,
  }) async {
    final bindings = _bindings ??= _SvgNoiseBindings(path);
    final result = await _runNoise((path, recipe.index, cssExtent, dpr));
    return SvgNoisePixels._(
      bindings,
      Pointer<Void>.fromAddress(result.$1),
      result.$2,
      result.$3,
      result.$4,
    );
  }
}

class SvgNoisePixels implements Finalizable {
  SvgNoisePixels._(
    this._owner,
    this._pointer,
    this.width,
    this.height,
    this.length,
  ) {
    _owner.finalizer.attach(this, _pointer, detach: this, externalSize: length);
  }
  final _SvgNoiseBindings _owner;
  final Pointer<Void> _pointer;
  final int width, height, length;
  bool _closed = false;
  Uint8List get bytes {
    if (_closed) throw StateError('SVG texture pixels are closed');
    return _owner.pixels(_pointer).asTypedList(length);
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _owner.finalizer.detach(this);
    _owner.close(_pointer);
  }
}

class _SvgNoiseBindings {
  _SvgNoiseBindings(String path) {
    final library = DynamicLibrary.open(path),
        version = library.lookupFunction<Uint32 Function(), int Function()>(
          'folia_noise_abi_version',
        );
    if (version() != 1) throw StateError('Unsupported SVG texture ABI');
    create = library
        .lookupFunction<
          Pointer<Void> Function(Int32, Double, Double),
          Pointer<Void> Function(int, double, double)
        >('folia_noise_create');
    width = library
        .lookupFunction<
          Int32 Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >('folia_noise_width');
    height = library
        .lookupFunction<
          Int32 Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >('folia_noise_height');
    size = library
        .lookupFunction<
          UintPtr Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >('folia_noise_size');
    pixels = library
        .lookupFunction<
          Pointer<Uint8> Function(Pointer<Void>),
          Pointer<Uint8> Function(Pointer<Void>)
        >('folia_noise_pixels');
    final release = library
        .lookup<NativeFunction<Void Function(Pointer<Void>)>>(
          'folia_noise_close',
        );
    close = release.asFunction<void Function(Pointer<Void>)>();
    finalizer = NativeFinalizer(release);
  }
  late final Pointer<Void> Function(int, double, double) create;
  late final int Function(Pointer<Void>) width, height, size;
  late final Pointer<Uint8> Function(Pointer<Void>) pixels;
  late final void Function(Pointer<Void>) close;
  late final NativeFinalizer finalizer;
}
