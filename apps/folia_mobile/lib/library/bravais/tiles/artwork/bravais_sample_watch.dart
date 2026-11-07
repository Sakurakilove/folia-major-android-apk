part of 'bravais_artwork_samples.dart';

// Views read through the bounded source cache, including eviction; removed widget listeners do not leave another permanent signal/cache entry.
class _SampleWatch<T> implements ValueListenable<T> {
  const _SampleWatch(this._read, this._listeners, this._url);
  final T Function() _read;
  final Map<String, Set<VoidCallback>> _listeners;
  final String _url;
  @override
  T get value => _read();
  @override
  void addListener(VoidCallback listener) =>
      (_listeners[_url] ??= {}).add(listener);
  @override
  void removeListener(VoidCallback listener) {
    final set = _listeners[_url];
    set?.remove(listener);
    if (set?.isEmpty ?? false) _listeners.remove(_url);
  }
}
