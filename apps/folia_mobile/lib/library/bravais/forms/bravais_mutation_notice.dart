import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../i18n/folia_strings.dart';
import '../../mutations/library_mutation_result.dart';

// Original seam-bottom notice, with a single cancellable expiry timer. Operation results after unmount do not resurrect notices or settle forms.
const bravaisNoticeMs = 4200;

enum BravaisNoticeTone { info, error }

class BravaisMutationNoticeLabels {
  const BravaisMutationNoticeLabels({
    required this.limitReached,
    required this.dislikeFailed,
    required this.failed,
    required this.stale,
    required this.unsupported,
  });
  factory BravaisMutationNoticeLabels.fromStrings(FoliaStrings strings) =>
      BravaisMutationNoticeLabels(
        limitReached: strings.t('home.noMoreDailyRecommendations'),
        dislikeFailed: strings.t('home.dislikeRecommendationFailed'),
        failed: strings.t('libraryBravaisCollection.actionFailed'),
        stale: strings.t('libraryBravaisCollection.actionStale'),
        unsupported: strings.t('libraryBravaisCollection.actionUnsupported'),
      );
  final String limitReached, dislikeFailed, failed, stale, unsupported;
}

typedef BravaisNoticeDescription = ({String text, BravaisNoticeTone tone});

BravaisNoticeDescription? describeBravaisMutationResult(
  LibraryMutationResult result,
  BravaisMutationNoticeLabels labels, {
  bool isDailyRemoval = false,
}) {
  if (result.ok || result.reason == LibraryMutationFailureReason.busy) {
    return null;
  }
  return switch (result.reason!) {
    LibraryMutationFailureReason.limitReached => (
      text: labels.limitReached,
      tone: BravaisNoticeTone.info,
    ),
    LibraryMutationFailureReason.stale => (
      text: labels.stale,
      tone: BravaisNoticeTone.info,
    ),
    LibraryMutationFailureReason.unsupported => (
      text: labels.unsupported,
      tone: BravaisNoticeTone.info,
    ),
    _ => (
      text: isDailyRemoval
          ? labels.dislikeFailed
          : result.message?.isNotEmpty == true
          ? '${labels.failed} · ${result.message}'
          : labels.failed,
      tone: BravaisNoticeTone.error,
    ),
  };
}

class BravaisSeamNotice {
  const BravaisSeamNotice({
    required this.seq,
    required this.text,
    required this.tone,
  });
  final int seq;
  final String text;
  final BravaisNoticeTone tone;
}

class BravaisMutationNotice extends ValueNotifier<BravaisSeamNotice?> {
  BravaisMutationNotice({required this.labels, required this.logFailure})
    : super(null);
  BravaisMutationNoticeLabels labels;
  final void Function(Object error, StackTrace stack) logFailure;
  int _seq = 0;
  Timer? _timer;
  bool _closed = false;

  void show(String text, BravaisNoticeTone tone) {
    if (_closed) return;
    final seq = ++_seq;
    value = BravaisSeamNotice(seq: seq, text: text, tone: tone);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: bravaisNoticeMs), () {
      _timer = null;
      if (!_closed && value?.seq == seq) value = null;
    });
  }

  Future<LibraryMutationResult?> run(
    Future<LibraryMutationResult> Function() action, {
    bool isDailyRemoval = false,
  }) async {
    LibraryMutationResult result;
    try {
      result = await action();
    } catch (error, stack) {
      logFailure(error, stack);
      result = const LibraryMutationResult.failure(
        LibraryMutationFailureReason.failed,
      );
    }
    if (_closed) return null;
    final described = describeBravaisMutationResult(
      result,
      labels,
      isDailyRemoval: isDailyRemoval,
    );
    if (described != null) show(described.text, described.tone);
    return result;
  }

  String? describe(
    LibraryMutationResult result, {
    bool isDailyRemoval = false,
  }) => describeBravaisMutationResult(
    result,
    labels,
    isDailyRemoval: isDailyRemoval,
  )?.text;

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
