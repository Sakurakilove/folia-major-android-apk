import 'dart:ffi';
import 'dart:typed_data';

import 'spectrum_snapshot.dart';

// Versioned C ABI: one allocation, two bounded native retries, then a 1024-byte copy into a reusable Dart array.
final class _AnalysisFrame extends Struct {
  @Uint32()
  external int abi;
  @Uint32()
  external int bytes;
  @Uint64()
  external int sequence;
  @Uint64()
  external int generation;
  @Int64()
  external int sampledAtNs;
  @Uint32()
  external int sampleRate;
  @Uint32()
  external int binCount;
  @Double()
  external double power;
  @Array(5)
  external Array<Double> bands;
  @Array(1024)
  external Array<Uint8> spectrum;
}

class SpectrumReader {
  SpectrumReader.open({DynamicLibrary? library}) {
    final native = library ?? DynamicLibrary.open('libfolia_analysis.so');
    final version = native.lookupFunction<Uint32 Function(), int Function()>(
      'folia_spectrum_abi_version',
    )();
    final bytes = native.lookupFunction<Uint32 Function(), int Function()>(
      'folia_spectrum_frame_size',
    )();
    if (version != 1 || bytes != sizeOf<_AnalysisFrame>() || bytes != 1112) {
      throw StateError('Incompatible native spectrum ABI: $version/$bytes');
    }
    _read = native
        .lookupFunction<
          Int32 Function(Pointer<_AnalysisFrame>, Uint32),
          int Function(Pointer<_AnalysisFrame>, int)
        >('folia_spectrum_read');
    _free = native
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('folia_spectrum_free_frame');
    _buffer = native
        .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
          'folia_spectrum_allocate_frame',
        )()
        .cast<_AnalysisFrame>();
    if (_buffer == nullptr) {
      throw StateError('Native spectrum allocation failed');
    }
    _nativeBins = (_buffer.cast<Uint8>() + 88).asTypedList(1024);
  }
  late final int Function(Pointer<_AnalysisFrame>, int) _read;
  late final void Function(Pointer<Void>) _free;
  late final Pointer<_AnalysisFrame> _buffer;
  late final Uint8List _nativeBins;
  bool _closed = false;

  bool sample(SpectrumSnapshot target) {
    if (_closed || _read(_buffer, 1112) != 1) return false;
    final frame = _buffer.ref;
    if (frame.abi != 1 ||
        frame.bytes != 1112 ||
        frame.binCount != 1024 ||
        frame.sequence == target.sequence) {
      return false;
    }
    target.bins.setRange(0, 1024, _nativeBins);
    for (var i = 0; i < 5; i++) {
      target.bands[i] = frame.bands[i];
    }
    target.sequence = frame.sequence;
    target.generation = frame.generation;
    target.sampledAtNs = frame.sampledAtNs;
    target.sampleRate = frame.sampleRate;
    target.binCount = frame.binCount;
    target.power = frame.power;
    return true;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _free(_buffer.cast<Void>());
  }
}
