import '../../mutations/library_mutation_result.dart';

// Original in-seam form reducer. Creating a playlist is nested within the picker, so one cancellation closes only that input before another cancellation closes the form.
class BravaisPlaylistScope {
  const BravaisPlaylistScope.collection() : entryKey = null;
  const BravaisPlaylistScope.entry(String this.entryKey);
  final String? entryKey;
  String get kind => entryKey == null ? 'collection' : 'entry';
}

sealed class BravaisFormState {
  const BravaisFormState(this.error);
  final String? error;
  String get kind;
  BravaisFormState withError(String? error);
}

class BravaisRenameForm extends BravaisFormState {
  const BravaisRenameForm(this.initial, {String? error}) : super(error);
  final String initial;
  @override
  String get kind => 'rename';
  @override
  BravaisRenameForm withError(String? error) =>
      BravaisRenameForm(initial, error: error);
}

class BravaisDeleteForm extends BravaisFormState {
  const BravaisDeleteForm({String? error}) : super(error);
  @override
  String get kind => 'confirm-delete';
  @override
  BravaisDeleteForm withError(String? error) => BravaisDeleteForm(error: error);
}

class BravaisPickPlaylistForm extends BravaisFormState {
  const BravaisPickPlaylistForm(
    this.scope, {
    this.creating = false,
    String? error,
  }) : super(error);
  final BravaisPlaylistScope scope;
  final bool creating;
  @override
  String get kind => 'pick-playlist';
  @override
  BravaisPickPlaylistForm withError(String? error) =>
      BravaisPickPlaylistForm(scope, creating: creating, error: error);
}

enum BravaisFormEventType {
  openRename,
  openDelete,
  openPick,
  startCreate,
  cancel,
  result,
}

class BravaisFormEvent {
  const BravaisFormEvent.openRename(String initial)
    : this._(BravaisFormEventType.openRename, initial: initial);
  const BravaisFormEvent.openDelete() : this._(BravaisFormEventType.openDelete);
  const BravaisFormEvent.openPick(BravaisPlaylistScope scope)
    : this._(BravaisFormEventType.openPick, scope: scope);
  const BravaisFormEvent.startCreate()
    : this._(BravaisFormEventType.startCreate);
  const BravaisFormEvent.cancel() : this._(BravaisFormEventType.cancel);
  const BravaisFormEvent.result(
    LibraryMutationResult result, {
    String? errorText,
  }) : this._(
         BravaisFormEventType.result,
         result: result,
         errorText: errorText,
       );
  const BravaisFormEvent._(
    this.type, {
    this.initial,
    this.scope,
    this.result,
    this.errorText,
  });
  final BravaisFormEventType type;
  final String? initial, errorText;
  final BravaisPlaylistScope? scope;
  final LibraryMutationResult? result;
}

BravaisFormState? reduceBravaisForm(
  BravaisFormState? state,
  BravaisFormEvent event,
) {
  switch (event.type) {
    case BravaisFormEventType.openRename:
      return BravaisRenameForm(event.initial!);
    case BravaisFormEventType.openDelete:
      return BravaisDeleteForm();
    case BravaisFormEventType.openPick:
      return BravaisPickPlaylistForm(event.scope!);
    case BravaisFormEventType.startCreate:
      return state is BravaisPickPlaylistForm
          ? BravaisPickPlaylistForm(state.scope, creating: true)
          : state;
    case BravaisFormEventType.cancel:
      return state is BravaisPickPlaylistForm && state.creating
          ? BravaisPickPlaylistForm(state.scope)
          : null;
    case BravaisFormEventType.result:
      if (state == null || event.result!.ok) return null;
      if (event.result!.reason == LibraryMutationFailureReason.busy) {
        return state;
      }
      return state.withError(event.errorText ?? event.result!.message);
  }
}

bool hasOpenBravaisForm(BravaisFormState? state) => state != null;
