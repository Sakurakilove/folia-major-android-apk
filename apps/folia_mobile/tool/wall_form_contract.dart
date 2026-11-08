import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/forms/bravais_collection_forms.dart';
import 'package:folia_mobile/library/bravais/forms/bravais_form_model.dart';
import 'package:folia_mobile/library/bravais/forms/bravais_mutation_notice.dart';
import 'package:folia_mobile/library/mutations/library_mutation_result.dart';

// Original in-flight action trace within the existing card case. Input updates during a request must change result text/back callbacks, while the operation retains its original controller/tracks.
Future<void> checkWallForms() async {
  final data = jsonDecode(
        File('test/fixtures/wall_forms_reference.json').readAsStringSync(),
      ),
      l = data['labels'],
      labels = BravaisMutationNoticeLabels(
        limitReached: l['limitReached'],
        dislikeFailed: l['dislikeFailed'],
        failed: l['failed'],
        stale: l['stale'],
        unsupported: l['unsupported'],
      );
  for (final step in data['notices']) {
    final described = describeBravaisMutationResult(
      _result(step['result']),
      labels,
      isDailyRemoval: step['isDailyRemoval'],
    );
    expect(
      described == null
          ? null
          : {'text': described.text, 'tone': described.tone.name},
      step['described'],
    );
  }
  BravaisFormState? state;
  for (final step in data['reducer']) {
    final event = step['event'], before = state;
    state = reduceBravaisForm(state, switch (event['type']) {
      'open-rename' => BravaisFormEvent.openRename(event['initial']),
      'open-delete' => const BravaisFormEvent.openDelete(),
      'open-pick' => BravaisFormEvent.openPick(_scope(event['scope'])),
      'start-create' => const BravaisFormEvent.startCreate(),
      'cancel' => const BravaisFormEvent.cancel(),
      _ => BravaisFormEvent.result(
        _result(event['result']),
        errorText: event['errorText'],
      ),
    });
    expect(_state(state), step['state'], reason: '$event');
    expect(identical(before, state), step['same'], reason: '$event');
    expect(hasOpenBravaisForm(state), step['open']);
  }
  final calls = <Map<String, Object?>>[],
      pending = <Future<void>>[],
      requests = <Completer<LibraryMutationResult>>[];
  var version = 0, available = true, runNull = false;
  BravaisCollectionFormInputs<String> inputs() {
    final v = version, nullResult = runNull;
    return BravaisCollectionFormInputs(
      mutations: available ? _Mutations(v, calls, requests) : null,
      displayTitle: 'Title $v',
      tracksFor: (scope) {
        calls.add({'op': 'tracks', 'version': v, 'scope': _scopeJson(scope)});
        return ['v$v:${scope.entryKey ?? 'all'}'];
      },
      run: (action) async {
        calls.add({'op': 'run', 'version': v});
        return nullResult ? null : await action();
      },
      describe: (result) {
        calls.add({
          'op': 'describe',
          'version': v,
          'result': _resultJson(result),
        });
        return !result.ok && result.reason != LibraryMutationFailureReason.busy
            ? 'v$v:${result.reason!.value}'
            : null;
      },
      onBack: () => calls.add({'op': 'back', 'version': v}),
    );
  }

  final forms = BravaisCollectionForms(inputs());
  try {
    for (final step in data['execution']) {
      final input = step['input'];
      switch (input['op']) {
        case 'rename':
          forms.openRename();
        case 'delete':
          forms.openDelete();
        case 'open-pick':
          forms.openPick(_scope(input['scope']));
        case 'start-create':
          forms.startCreate();
        case 'cancel':
          forms.cancel();
        case 'begin-submit':
          pending.add(forms.submit(input['text']));
        case 'begin-pick':
          pending.add(forms.pick(input['playlistId']));
        case 'submit':
          await forms.submit(input['text']);
        case 'pick':
          await forms.pick(input['playlistId']);
        case 'complete':
          requests.removeAt(0).complete(_result(input['result']));
          await pending.removeAt(0);
        case 'update':
          version = input['version'];
          available = input['available'] != false;
          runNull = input['runNull'] == true;
          forms.inputs = inputs();
      }
      expect(_state(forms.value), step['state'], reason: '$input');
      expect(calls, step['calls'], reason: '$input');
    }
    expect(requests, isEmpty);
    expect(pending, isEmpty);
  } finally {
    forms.dispose();
  }
  final errors = <Object>[],
      notice = BravaisMutationNotice(
        labels: labels,
        logFailure: (error, stack) => errors.add(error),
      );
  final failed = await notice.run(() async => throw StateError('upstream'));
  expect(failed?.reason, LibraryMutationFailureReason.failed);
  expect(errors.single, isA<StateError>());
  expect(notice.value?.text, labels.failed);
  final deferred = Completer<LibraryMutationResult>(),
      afterUnmount = notice.run(() => deferred.future);
  notice.dispose();
  deferred.complete(const LibraryMutationResult.success());
  expect(await afterUnmount, isNull);
}

Future<void> checkWallNoticeExpiry(WidgetTester tester) async {
  final notice = BravaisMutationNotice(
    labels: const BravaisMutationNoticeLabels(
      limitReached: 'limit',
      dislikeFailed: 'dislike',
      failed: 'failed',
      stale: 'stale',
      unsupported: 'unsupported',
    ),
    logFailure: (error, stack) => fail('$error'),
  );
  try {
    notice.show('same', BravaisNoticeTone.info);
    expect(notice.value?.seq, 1);
    await tester.pump(const Duration(milliseconds: 4100));
    notice.show('same', BravaisNoticeTone.info);
    expect(notice.value?.seq, 2);
    await tester.pump(const Duration(milliseconds: 100));
    expect(notice.value?.seq, 2);
    await tester.pump(const Duration(milliseconds: 4100));
    expect(notice.value, isNull);
  } finally {
    notice.dispose();
  }
}

LibraryMutationResult _result(Map json) => json['ok']
    ? const LibraryMutationResult.success()
    : LibraryMutationResult.failure(
        LibraryMutationFailureReason.values.firstWhere(
          (v) => v.value == json['reason'],
        ),
        message: json['message'],
      );
Map<String, Object?> _resultJson(LibraryMutationResult result) => {
  'ok': result.ok,
  if (!result.ok) 'reason': result.reason!.value,
  if (result.message != null) 'message': result.message,
};
BravaisPlaylistScope _scope(Map json) => json['kind'] == 'entry'
    ? BravaisPlaylistScope.entry(json['entryKey'])
    : const BravaisPlaylistScope.collection();
Map<String, Object?> _scopeJson(BravaisPlaylistScope scope) => {
  'kind': scope.kind,
  if (scope.entryKey != null) 'entryKey': scope.entryKey,
};
Map<String, Object?>? _state(BravaisFormState? state) => state == null
    ? null
    : {
        'kind': state.kind,
        'error': state.error,
        if (state is BravaisRenameForm) 'initial': state.initial,
        if (state is BravaisPickPlaylistForm) ...{
          'scope': _scopeJson(state.scope),
          'creating': state.creating,
        },
      };

class _Mutations implements BravaisCollectionFormMutations<String> {
  _Mutations(this.version, this.calls, this.requests);
  final int version;
  final List<Map<String, Object?>> calls;
  final List<Completer<LibraryMutationResult>> requests;
  Future<LibraryMutationResult> _request(
    String op,
    Map<String, Object?> payload,
  ) {
    calls.add({'op': op, 'version': version, ...payload});
    final request = Completer<LibraryMutationResult>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<LibraryMutationResult> rename(String value) =>
      _request('rename', {'text': value});
  @override
  Future<LibraryMutationResult> deleteCollection() => _request('delete', {});
  @override
  Future<LibraryMutationResult> createPlaylist(
    String value,
    List<String> tracks,
  ) => _request('create', {'text': value, 'tracks': tracks});
  @override
  Future<LibraryMutationResult> addToPlaylist(
    Object playlistId,
    List<String> tracks,
  ) => _request('add', {'playlistId': playlistId, 'tracks': tracks});
}
