import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/stage/bravais_session_focus.dart';
import 'package:folia_mobile/library/session/library_browse_session.dart';

// Small extension of the existing card case: actual baseline store/hook outputs, including no-op notifications, 32-session eviction and overlapping surface cleanup.
void checkWallSessions(Map data) {
  final store = _ObservedSessions(),
      instances = <String, BravaisSessionFocus>{};
  var notifications = 0;
  store.addListener(() => notifications++);
  Map<String, Object?> snapshot() => {
    'order': store.value.order,
    'sessions': {
      for (final entry in store.value.sessions.entries)
        entry.key: {
          'query': entry.value.query,
          'focusedEntryKey': entry.value.focusedEntryKey,
        },
    },
    'notifications': notifications,
  };
  try {
    for (final step in data['steps']) {
      final input = step['input'], before = store.value;
      switch (input['op']) {
        case 'query':
          store.setQuery(input['key'], input['value']);
        case 'focus':
          store.setFocusedEntry(input['key'], input['value']);
        case 'clear':
          store.clearSession(input['key']);
      }
      expect(identical(before, store.value), step['same'], reason: '$input');
      expect(
        store.generation(input['key']),
        step['generation'],
        reason: '$input',
      );
      final actual = snapshot();
      for (final key in actual.keys) {
        expect(actual[key], step[key], reason: '$input / $key');
      }
    }
    store.record = true;
    for (final step in data['focus']) {
      final input = step['input'];
      switch (input['op']) {
        case 'seed':
          store.record = false;
          store.setFocusedEntry(input['key'], input['value']);
          store.record = true;
        case 'mount':
          store.mountId = input['id'];
          instances[input['id']] = BravaisSessionFocus(
            store: store,
            sessionKey: input['key'],
          );
        case 'note':
          instances[input['id']]!.noteFocus(input['value']);
        case 'persist':
          if (input.containsKey('value')) {
            instances[input['id']]!.persistFocus(input['value']);
          } else {
            instances[input['id']]!.persistFocus();
          }
        case 'unmount':
          instances[input['id']]!.dispose();
        case 'clear':
          store.clearSession(input['key']);
        case 'flush':
          store.flush(input['key']);
      }
      final actual = {
        ...snapshot(),
        'initials': {
          for (final entry in instances.entries)
            entry.key: entry.value.initialKey,
        },
        'writes': store.writes,
        'lifecycle': store.lifecycle,
      };
      for (final key in actual.keys) {
        expect(actual[key], step[key], reason: '$input / $key');
      }
    }
  } finally {
    for (final instance in instances.values) {
      instance.dispose();
    }
    store.dispose();
  }
}

class _ObservedSessions extends LibraryBrowseSessionStore {
  bool record = false;
  String? mountId;
  final writes = <Map<String, Object?>>[], lifecycle = <String>[];
  @override
  void setFocusedEntry(String key, String? focusedEntryKey) {
    if (record) {
      writes.add({'key': key, 'value': focusedEntryKey});
      lifecycle.add('write:$key:${focusedEntryKey ?? 'null'}');
    }
    super.setFocusedEntry(key, focusedEntryKey);
  }

  @override
  void Function() registerFlush(String key, void Function() flush) {
    final unregister = super.registerFlush(key, flush), id = mountId;
    return () {
      lifecycle.add('unregister:$id');
      unregister();
    };
  }
}
