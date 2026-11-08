import '../../session/library_browse_session.dart';

// Original surface-owned focus lease: note locally on discrete focus changes; persist before nesting/play, and flush only if the session was not cleared since mount.
class BravaisSessionFocus {
  BravaisSessionFocus({required this.store, required this.sessionKey})
    : initialKey = store.read(sessionKey).focusedEntryKey,
      _mountGeneration = store.generation(sessionKey) {
    _current = initialKey;
    _unregister = store.registerFlush(sessionKey, flushFocus);
  }

  final LibraryBrowseSessionStore store;
  final String sessionKey;
  final String? initialKey;
  final int _mountGeneration;
  String? _current;
  bool _touched = false, _closed = false;
  late final void Function() _unregister;
  static const _retainKey = Object();

  void noteFocus(String? key) {
    if (_closed) return;
    _current = key;
    _touched = true;
  }

  // Omitted and explicit null differ in the source: only explicit null clears the current key.
  void persistFocus([Object? key = _retainKey]) {
    if (_closed) return;
    if (!identical(key, _retainKey)) _current = key as String?;
    _touched = true;
    store.setFocusedEntry(sessionKey, _current);
  }

  void flushFocus() {
    if (_closed || !_touched || _current == null || _current!.isEmpty) return;
    if (store.generation(sessionKey) != _mountGeneration) return;
    store.setFocusedEntry(sessionKey, _current);
  }

  void dispose() {
    if (_closed) return;
    _unregister();
    flushFocus();
    _closed = true;
  }
}
