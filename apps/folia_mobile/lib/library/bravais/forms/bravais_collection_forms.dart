import 'package:flutter/foundation.dart';

import '../../mutations/library_mutation_result.dart';
import 'bravais_form_model.dart';

// Actual collection form executor. The surface supplies complete tracks and mutation operations, never reconstructed from a wall card's display text.
abstract interface class BravaisCollectionFormMutations<T> {
  Future<LibraryMutationResult> rename(String value);
  Future<LibraryMutationResult> deleteCollection();
  Future<LibraryMutationResult> createPlaylist(String value, List<T> tracks);
  Future<LibraryMutationResult> addToPlaylist(
    Object playlistId,
    List<T> tracks,
  );
}

typedef BravaisRunMutation = Future<LibraryMutationResult?> Function(
  Future<LibraryMutationResult> Function() action,
);

class BravaisCollectionFormInputs<T> {
  const BravaisCollectionFormInputs({
    required this.mutations,
    required this.displayTitle,
    required this.tracksFor,
    required this.onBack,
    required this.run,
    required this.describe,
  });
  final BravaisCollectionFormMutations<T>? mutations;
  final String displayTitle;
  final List<T> Function(BravaisPlaylistScope scope) tracksFor;
  final VoidCallback onBack;
  final BravaisRunMutation run;
  final String? Function(LibraryMutationResult result) describe;
}

class BravaisCollectionForms<T> extends ValueNotifier<BravaisFormState?> {
  BravaisCollectionForms(this.inputs) : super(null);
  BravaisCollectionFormInputs<T> inputs;
  bool _closed = false;

  void _dispatch(BravaisFormEvent event) {
    if (!_closed) value = reduceBravaisForm(value, event);
  }

  void openRename() =>
      _dispatch(BravaisFormEvent.openRename(inputs.displayTitle));
  void openDelete() => _dispatch(const BravaisFormEvent.openDelete());
  void openPick(BravaisPlaylistScope scope) =>
      _dispatch(BravaisFormEvent.openPick(scope));
  void startCreate() => _dispatch(const BravaisFormEvent.startCreate());
  void cancel() => _dispatch(const BravaisFormEvent.cancel());

  void _settle(LibraryMutationResult? result) {
    if (result == null) return;
    _dispatch(
      BravaisFormEvent.result(result, errorText: inputs.describe(result)),
    );
  }

  Future<void> submit(String text) async {
    if (_closed) return;
    final current = value, snapshot = inputs, controller = snapshot.mutations;
    if (current == null || controller == null) return;
    switch (current) {
      case BravaisRenameForm():
        _settle(await snapshot.run(() => controller.rename(text)));
      case BravaisDeleteForm():
        final result = await snapshot.run(controller.deleteCollection);
        _settle(result);
        if (result?.ok == true) inputs.onBack();
      case BravaisPickPlaylistForm():
        if (current.creating) {
          _settle(
            await snapshot.run(
              () => controller.createPlaylist(
                text,
                snapshot.tracksFor(current.scope),
              ),
            ),
          );
        }
    }
  }

  Future<void> pick(Object playlistId) async {
    if (_closed) return;
    final current = value, snapshot = inputs, controller = snapshot.mutations;
    if (current is! BravaisPickPlaylistForm || controller == null) return;
    _settle(
      await snapshot.run(
        () => controller.addToPlaylist(
          playlistId,
          snapshot.tracksFor(current.scope),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    super.dispose();
  }
}
