import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'native_artwork_descriptors.dart';
import 'native_url.dart';
import 'wall_artwork_queue.dart';

// One sparse open request returns a claim ticket. Encoded bytes stay in the native file/engine path; no image payload or rendered frame crosses MethodChannel.
class NativeArtworkBufferLoader {
  NativeArtworkBufferLoader({
    required this.urls,
    MethodChannel? channel,
    this.resolveSource,
    this.headersForUrl,
    NativeArtworkDescriptors? descriptors,
  }) : _channel = channel ?? const MethodChannel('top.izuna.folia/artwork'),
       // ignore: prefer_initializing_formals
       _descriptors = descriptors;
  final NativeUrlLibrary urls;
  final Future<String> Function(String)? resolveSource;
  final Future<Map<String, String>> Function(String)? headersForUrl;
  final MethodChannel _channel;
  NativeArtworkDescriptors? _descriptors;
  final _active = <ArtworkCancellation>{};
  static var _sequence = 0;
  static final _requestIds = <int>{};
  bool _closed = false;
  int _id() {
    do {
      _sequence = (_sequence + 1) & 0x7fffffff;
    } while (_requestIds.contains(_sequence));
    _requestIds.add(_sequence);
    return _sequence;
  }

  Future<ui.ImmutableBuffer> load(
    String source,
    ArtworkCancellation signal,
  ) async {
    if (_closed) throw const ArtworkCancelled();
    final local = ArtworkCancellation();
    _active.add(local);
    signal.add(local.cancel);
    NativeArtworkLease? lease;
    int? request;
    void cancelNative() {
      if (request == null) return;
      unawaited(
        _channel
            .invokeMethod<void>('cancel', {'id': request})
            .catchError((Object _) {}),
      );
    }

    try {
      local.throwIfCancelled();
      final resolved = resolveSource == null
              ? source
              : await resolveSource!(source),
          url = urls.parse(resolved);
      if (url == null) {
        throw StateError(
          'Artwork source requires an absolute native asset URI',
        );
      }
      final String address;
      try {
        address = url.href;
      } finally {
        url.dispose();
      }
      if (address.startsWith('data:')) {
        local.throwIfCancelled();
        final data = (_descriptors ??= NativeArtworkDescriptors())
            .decodeDataUri(address);
        try {
          final buffer = await ui.ImmutableBuffer.fromUint8List(data.bytes);
          if (local.cancelled) {
            buffer.dispose();
            throw const ArtworkCancelled();
          }
          return buffer;
        } finally {
          data.dispose();
        }
      }
      final headers =
          await headersForUrl?.call(address) ?? const <String, String>{};
      local.throwIfCancelled();
      request = _id();
      local.add(cancelNative);
      local.throwIfCancelled();
      final response = await _channel.invokeMapMethod<String, dynamic>('open', {
        'id': request,
        'url': address,
        'headers': headers,
      });
      final ticket = response?['ticket'];
      if (ticket is! int || ticket <= 0) {
        throw StateError('Artwork host returned no descriptor ticket');
      }
      final descriptors = _descriptors ??= NativeArtworkDescriptors();
      lease = descriptors.claim(ticket);
      if (lease == null) throw const ArtworkCancelled();
      local.throwIfCancelled();
      final buffer = await ui.ImmutableBuffer.fromFilePath(
        '/proc/self/fd/${lease.fd}',
      );
      if (local.cancelled) {
        buffer.dispose();
        throw const ArtworkCancelled();
      }
      return buffer;
    } on PlatformException catch (failure) {
      if (local.cancelled ||
          const {'cancelled', 'busy', 'closed'}.contains(failure.code)) {
        throw const ArtworkCancelled();
      }
      rethrow;
    } catch (_) {
      if (local.cancelled) throw const ArtworkCancelled();
      rethrow;
    } finally {
      lease?.dispose();
      local.remove(cancelNative);
      signal.remove(local.cancel);
      _active.remove(local);
      if (request != null) _requestIds.remove(request);
    }
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    for (final signal in _active.toList(growable: false)) {
      signal.cancel();
    }
  }
}
