import 'package:flutter/foundation.dart';

// Original in-memory cross-suite query/focus store. Layout coordinates stay with each suite; session clearing changes generation even when no session exists.
class LibraryBrowseSession {
  const LibraryBrowseSession({this.query = '', this.focusedEntryKey});
  final String query;
  final String? focusedEntryKey;
}

class LibraryBrowseSessionState {
  const LibraryBrowseSessionState({
    this.sessions = const {},
    this.order = const [],
  });
  final Map<String, LibraryBrowseSession> sessions;
  final List<String> order;
}

class LibraryBrowseSessionStore
    extends ValueNotifier<LibraryBrowseSessionState> {
  LibraryBrowseSessionStore() : super(const LibraryBrowseSessionState());

  static const maxSessions = 32;
  static const _empty = LibraryBrowseSession();
  final _generations = <String, int>{};
  final _flushers = <String, VoidCallback>{};

  LibraryBrowseSession read(String key) => value.sessions[key] ?? _empty;
  int generation(String key) => _generations[key] ?? 0;

  void setQuery(String key, String query) {
    final current = read(key);
    if (current.query == query) return;
    _write(
      key,
      LibraryBrowseSession(
        query: query,
        focusedEntryKey: current.focusedEntryKey,
      ),
    );
  }

  void setFocusedEntry(String key, String? focusedEntryKey) {
    final current = read(key);
    if (current.focusedEntryKey == focusedEntryKey) return;
    _write(
      key,
      LibraryBrowseSession(
        query: current.query,
        focusedEntryKey: focusedEntryKey,
      ),
    );
  }

  void _write(String key, LibraryBrowseSession session) {
    final sessions = {...value.sessions, key: session},
        order = [...value.order.where((old) => old != key), key];
    while (order.length > maxSessions) {
      sessions.remove(order.removeAt(0));
    }
    value = LibraryBrowseSessionState(
      sessions: Map.unmodifiable(sessions),
      order: List.unmodifiable(order),
    );
  }

  void clearSession(String key) {
    _generations[key] = generation(key) + 1;
    if (!value.sessions.containsKey(key)) return;
    value = LibraryBrowseSessionState(
      sessions: Map.unmodifiable({...value.sessions}..remove(key)),
      order: List.unmodifiable(value.order.where((old) => old != key)),
    );
  }

  // A replaced surface owns the new callback. The old surface's cleanup cannot unregister it.
  VoidCallback registerFlush(String key, VoidCallback flush) {
    _flushers[key] = flush;
    return () {
      if (identical(_flushers[key], flush)) _flushers.remove(key);
    };
  }

  void flush(String key) => _flushers[key]?.call();

  @override
  void dispose() {
    _flushers.clear();
    _generations.clear();
    super.dispose();
  }
}
