import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_tags.dart';
import 'package:one_second_diary/features/clips/data/tag_batch.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/tag_batch_event.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/domain/profiles_snapshot.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/tags_state.dart';

/// Settings › Tags, and the Settings tab's tag count.
///
/// [load] reads the vocabulary (`ClipTags.vocabulary`, every loaded
/// profile) and keeps it fresh: tags change from anywhere (a clip edited in
/// the viewer, a profile added, the backfill reading clips after a
/// reinstall), so the cubit follows every loaded profile's library through
/// `ClipRepository.watch` and reads again on each snapshot. A colour change
/// (`TagColors.changes`) bumps [TagsState.colorsVersion] so the chips
/// repaint.
///
/// [rename] and [remove] run a `TagBatch` over the clips concerned, one at
/// a time; the cubit reports its progress in [TagsState.batch] and holds
/// the [CancelToken] [stopBatch] cancels. One batch runs at a time.
class TagsCubit extends Cubit<TagsState> {
  TagsCubit({
    required this._tags,
    required this._batch,
    required this._colors,
    required this._clips,
    required this._profiles,
    required this._logger,
  }) : super(const TagsState());

  final ClipTags _tags;
  final TagBatch _batch;
  final TagColors _colors;
  final ClipRepository _clips;
  final ProfilesRepository _profiles;
  final AppLogger _logger;

  static const String _tag = 'TAGS';

  StreamSubscription<ProfilesSnapshot>? _profilesSub;
  final Map<ProfileKey, StreamSubscription<ClipIndex>> _libraries =
      <ProfileKey, StreamSubscription<ClipIndex>>{};
  StreamSubscription<void>? _colorsSub;

  /// The token of the running batch.
  CancelToken? _cancel;

  /// Reads the vocabulary and follows the libraries and the colours.
  void load() {
    _profilesSub ??= _profiles.watch().listen((ProfilesSnapshot snapshot) {
      _follow(snapshot.profiles);
      _refresh();
    });
    _colorsSub ??= _colors.changes.listen((_) {
      if (!isClosed) {
        emit(state.copyWith(colorsVersion: state.colorsVersion + 1));
      }
    });
    _refresh();
  }

  /// Follows the library of each of [profiles], and no other.
  void _follow(List<Profile> profiles) {
    final Set<ProfileKey> keys = <ProfileKey>{
      for (final Profile profile in profiles) profile.key,
    };
    for (final ProfileKey key in _libraries.keys.toList()) {
      if (!keys.contains(key)) unawaited(_libraries.remove(key)!.cancel());
    }
    for (final ProfileKey key in keys) {
      _libraries.putIfAbsent(
        key,
        () => _clips
            .watch(key)
            .listen(
              (_) => _refresh(),
              // A failed scan is logged and shown by the repository's
              // owners; the vocabulary just has nothing from that profile.
              onError: (Object _) {},
            ),
      );
    }
  }

  void _refresh() {
    if (isClosed) return;
    emit(state.copyWith(tags: _tags.vocabulary(), loaded: true));
  }

  /// Gives every clip tagged [from] the tag [to] instead (a merge when
  /// clips already carry [to]). [to] must pass `TagName.validate`.
  Future<void> rename(String from, String to) => _run(
    TagBatchKind.rename,
    from,
    (CancelToken token) => _batch.rename(from, to, cancelToken: token),
  );

  /// Takes [tag] off every clip that carries it.
  Future<void> remove(String tag) => _run(
    TagBatchKind.remove,
    tag,
    (CancelToken token) => _batch.remove(tag, cancelToken: token),
  );

  /// Stops the running batch after the clip in flight.
  void stopBatch() => _cancel?.cancel();

  /// Chooses swatch [index] for [tag], or, with null, its automatic colour.
  /// The colour applies at once; a store that fails is logged and counted
  /// in [TagsState.colorSaveFailures].
  Future<void> setColor(String tag, int? index) async {
    try {
      await _colors.set(tag, index);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not store the colour of "$tag"',
        error: error,
        stackTrace: stackTrace,
      );
      if (!isClosed) {
        emit(state.copyWith(colorSaveFailures: state.colorSaveFailures + 1));
      }
    }
  }

  Future<void> _run(
    TagBatchKind kind,
    String tag,
    Stream<TagBatchEvent> Function(CancelToken token) start,
  ) async {
    if (state.isBatchRunning) return;
    final CancelToken token = CancelToken();
    _cancel = token;
    emit(
      state.copyWith(
        batch: TagBatchRun(kind: kind, tag: tag),
      ),
    );
    try {
      await for (final TagBatchEvent event in start(token)) {
        if (isClosed) return;
        final TagBatchRun run = state.batch!;
        switch (event) {
          case TagBatchProgress(:final int done, :final int total):
            emit(
              state.copyWith(
                batch: run.copyWith(done: done, total: total),
              ),
            );
          case TagBatchFinished():
            emit(state.copyWith(batch: run.copyWith(finished: event)));
        }
      }
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'The tag batch on "$tag" broke off',
        error: error,
        stackTrace: stackTrace,
      );
      if (!isClosed) emit(state.copyWith(clearBatch: true));
    } finally {
      if (identical(_cancel, token)) _cancel = null;
    }
    _refresh();
  }

  @override
  Future<void> close() async {
    _cancel?.cancel();
    await _profilesSub?.cancel();
    await _colorsSub?.cancel();
    for (final StreamSubscription<ClipIndex> sub in _libraries.values) {
      await sub.cancel();
    }
    _libraries.clear();
    return super.close();
  }
}
