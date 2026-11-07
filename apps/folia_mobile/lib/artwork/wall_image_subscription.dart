import 'package:flutter/painting.dart';

// Native stream ownership is independent of the widget tree. Hidden consumers retain the completer but stop animated frame delivery; the receiver owns each ImageInfo.
class WallImageSubscription {
  WallImageSubscription({required this.onImage, required this.onClear});
  final void Function(ImageInfo) onImage;
  final void Function() onClear;
  ImageProvider<String>? _provider;
  ImageConfiguration _configuration = ImageConfiguration.empty;
  ImageStream? _stream;
  ImageStreamCompleterHandle? _keepAlive;
  bool _attached = false, _enabled = false, _listening = false, _closed = false;
  late final _listener = ImageStreamListener(
    (info, _) {
      if (_closed) {
        info.dispose();
      } else {
        onImage(info);
      }
    },
    onError: (Object error, StackTrace? stack) {
      if (!_closed) onClear();
    },
  );
  void update(
    ImageProvider<String>? provider,
    ImageConfiguration configuration, {
    required bool enabled,
  }) {
    if (_closed) return;
    final changed = provider != _provider || configuration != _configuration;
    _provider = provider;
    _configuration = configuration;
    _enabled = enabled;
    if (changed) {
      _forget();
      onClear();
    }
    _sync();
  }

  void setAttached(bool attached) {
    if (_closed) return;
    _attached = attached;
    _sync();
  }

  void _sync() {
    if (!_attached || !_enabled || _provider == null) {
      if (_listening) {
        _keepAlive = _stream!.completer?.keepAlive();
        _stream!.removeListener(_listener);
        _listening = false;
      }
      return;
    }
    _stream ??= _provider!.resolve(_configuration);
    if (!_listening) {
      _listening = true;
      _stream!.addListener(_listener);
      _keepAlive?.dispose();
      _keepAlive = null;
    }
  }

  void _forget() {
    if (_listening) _stream?.removeListener(_listener);
    _listening = false;
    _keepAlive?.dispose();
    _keepAlive = null;
    _stream = null;
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _forget();
  }
}
