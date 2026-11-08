// Original core mutation discriminant. Display text and operation capability checks remain with their respective renderer and controller.
enum LibraryMutationFailureReason {
  busy('busy'),
  stale('stale'),
  unsupported('unsupported'),
  limitReached('limit-reached'),
  failed('failed');

  const LibraryMutationFailureReason(this.value);
  final String value;
}

class LibraryMutationResult {
  const LibraryMutationResult.success() : reason = null, message = null;
  const LibraryMutationResult.failure(
    LibraryMutationFailureReason this.reason, {
    this.message,
  });
  final LibraryMutationFailureReason? reason;
  final String? message;
  bool get ok => reason == null;
}
