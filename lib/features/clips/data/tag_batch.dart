import 'dart:async';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_tags.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/tag_batch_event.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Renames, merges or removes a tag on every clip that carries it, across
/// every loaded profile (Settings › Tags).
///
/// Each clip is rewritten through [ClipTags.setTags], one after the other
/// (each is a remux and, on Android, possibly a consent prompt), so a run
/// can be long: it reports [TagBatchProgress] after each clip and ends
/// with [TagBatchFinished]. [CancelToken.cancel] stops it after the clip in
/// flight; the clips already rewritten keep the change (each one is
/// atomic), the others are as they were. A clip that fails is logged,
/// counted and skipped; the run goes on.
///
/// Kept a plain class (not final) so the Settings tests can fake it.
class TagBatch {
  TagBatch({
    required this._tags,
    required this._clips,
    required this._colors,
    required this._logger,
  });

  final ClipTags _tags;
  final ClipRepository _clips;
  final TagColors _colors;
  final AppLogger _logger;

  static const String _tag = 'TAGS';

  /// The clips of every loaded profile that carry [tag].
  List<ClipRef> clipsWith(String tag) {
    final String key = TagName.fold(tag);
    return <ClipRef>[
      for (final MapEntry<ProfileKey, ClipIndex> entry
          in _clips.snapshots.entries)
        for (final ClipRef clip in entry.value.newestFirst)
          if (entry.value
              .tagsOf(clip)
              .any((String t) => TagName.fold(t) == key))
            clip,
    ];
  }

  /// Gives every clip tagged [from] the tag [to] instead (a merge when
  /// clips already carry [to]: they end up with it once). [to] must pass
  /// `TagName.validate`; the caller checks. The colour chosen for [from]
  /// moves to [to] unless [to] has one.
  Stream<TagBatchEvent> rename(
    String from,
    String to, {
    required CancelToken cancelToken,
  }) {
    final String target = TagName.clean(to);
    return _run(
      from,
      (List<String> tags) => <String>[
        for (final String tag in tags)
          if (!TagName.same(tag, from)) tag,
        target,
      ],
      cancelToken: cancelToken,
      onDone: () => _colors.rename(from, target),
    );
  }

  /// Takes [tag] off every clip that carries it.
  Stream<TagBatchEvent> remove(
    String tag, {
    required CancelToken cancelToken,
  }) => _run(
    tag,
    (List<String> tags) => <String>[
      for (final String other in tags)
        if (!TagName.same(other, tag)) other,
    ],
    cancelToken: cancelToken,
    onDone: () => _colors.set(tag, null),
  );

  Stream<TagBatchEvent> _run(
    String tag,
    List<String> Function(List<String> tags) rewrite, {
    required CancelToken cancelToken,
    required Future<void> Function() onDone,
  }) async* {
    final List<ClipRef> clips = clipsWith(tag);
    int done = 0;
    int updated = 0;
    int failed = 0;
    bool stopped = false;
    yield TagBatchProgress(done: 0, total: clips.length);
    for (final ClipRef clip in clips) {
      if (cancelToken.isCancelled) {
        stopped = true;
        break;
      }
      try {
        await _tags.setTags(clip, rewrite(_tags.tagsOf(clip)));
        updated++;
      } on Object catch (error, stackTrace) {
        failed++;
        _logger.warning(
          _tag,
          'Could not rewrite the tags of ${clip.relPath}',
          error: error,
          stackTrace: stackTrace,
        );
      }
      done++;
      yield TagBatchProgress(done: done, total: clips.length);
    }
    if (!stopped && failed == 0) {
      try {
        await onDone();
      } on Object catch (error, stackTrace) {
        _logger.warning(
          _tag,
          'Could not update the colour of "$tag"',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    _logger.info(
      _tag,
      'Tag batch on "$tag": $updated updated, $failed failed'
      '${stopped ? ', stopped' : ''}',
    );
    yield TagBatchFinished(updated: updated, failed: failed, stopped: stopped);
  }
}
