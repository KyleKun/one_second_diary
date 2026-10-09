import 'dart:async';
import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/share_gateway.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/diary/data/clip_captions.dart';
import 'package:one_second_diary/features/diary/data/clip_filtering.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/viewer_state.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

/// The viewer, one per viewer: the clip shown, from its profile's clip
/// index in memory.
///
/// - Previous and next step through a day's clips first, then to the
///   closest recorded days, skipping missed ones and crossing months;
///   opened from a filtered Diary (`ViewerArgs.filter`), through the clips
///   the filter keeps only.
/// - The sound is the user's last choice (`calendarAutoSound`, sound on by
///   default): the viewer is opened on purpose, unlike the Diary's muted
///   mini player. Its toggle writes the choice, which the Diary follows.
/// - Deleting the clip shown (for good) moves on to the next recorded
///   clip, or the previous after the last, or closes the viewer when none
///   is left. A clip deleted elsewhere does the same.
class ViewerCubit extends Cubit<ViewerState> {
  ViewerCubit({
    required ViewerArgs args,
    required ProfilesRepository profiles,
    required ClipRepository clips,
    required this._captions,
    required ClipFiltering filtering,
    required this._store,
    required this._share,
    required this._paths,
    required SettingsRepository settings,
    required this._logger,
  }) : _settings = settings,
       _filtering = filtering,
       super(
         ViewerState(
           profile: _profileOf(args.clip, profiles),
           clip: args.clip,
           opened: args.clip,
           index: clips.snapshotOf(args.clip.profile),
           filter: args.filter,
           filteredIndex: switch (clips.snapshotOf(args.clip.profile)) {
             final ClipIndex index => filtering.of(index, args.filter),
             null => null,
           },
           caption: _captions.of(args.clip),
           muted: !settings.calendarAutoSound.value,
         ),
       ) {
    _clipChanges = clips.watch(args.clip.profile).listen(_indexChanged);
    _soundChanges = settings.calendarAutoSound.changes.listen((bool on) {
      if (!_storingSound) emit(state.copyWith(muted: !on));
    });
  }

  final ClipCaptions _captions;
  final ClipFiltering _filtering;
  final ClipStore _store;
  final ShareGateway _share;
  final AppPaths _paths;
  final SettingsRepository _settings;
  final AppLogger _logger;

  static const String _tag = 'CALENDAR';

  late final StreamSubscription<ClipIndex> _clipChanges;
  late final StreamSubscription<bool> _soundChanges;
  bool _storingSound = false;

  void showPrevious() => _show(state.previous);

  void showNext() => _show(state.next);

  /// The sound toggle: remembers the choice (`calendarAutoSound`).
  Future<void> toggleSound() async {
    final bool on = state.muted;
    emit(state.copyWith(muted: !on));
    _storingSound = true;
    try {
      await _settings.calendarAutoSound.set(on);
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not remember the viewer\'s sound choice',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _storingSound = false;
    }
  }

  /// Opens the system share sheet on the clip's file as it is stored (its
  /// burned stamp, its subtitles), anchored at [origin] (iPad).
  Future<void> share({Rect? origin}) => _share.shareFiles(<String>[
    _paths.absoluteFromVideos(state.clip.relPath),
  ], origin: origin);

  /// Deletes the clip shown for good (`ClipStore.delete`), then shows the
  /// next recorded clip, or the previous after the last, or closes. The
  /// state says it runs, then whether it worked, every time.
  Future<void> deleteShown() async {
    final ClipRef clip = state.clip;
    final ClipRef? after = state.next ?? state.previous;
    emit(state.copyWith(deletion: ClipDeletion.deleting, deletedClip: clip));
    try {
      // The "Video deleted" snackbar offers Undo, and makes the delete
      // final when it leaves (`DeletedClipSnackbar`).
      await _store.delete(clip);
      _logger.info(_tag, 'Deleted ${clip.relPath} from the viewer');
      final ViewerState deleted = state.copyWith(
        deletion: ClipDeletion.deleted,
      );
      emit(
        state.clip != clip
            ? deleted
            : after == null
            ? deleted.copyWith(closed: true)
            : _showing(deleted, after),
      );
    } on Exception catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not delete ${clip.relPath}',
        error: error,
        stackTrace: stackTrace,
      );
      emit(state.copyWith(deletion: ClipDeletion.failed));
    }
  }

  /// The user uncovered the private [clip] (the player's tap): its caption
  /// shows with its picture.
  void reveal(ClipRef clip) {
    if (state.revealed.contains(clip) && !state.hidden.contains(clip)) return;
    emit(
      state.copyWith(
        revealed: <ClipRef>{...state.revealed, clip},
        hidden: <ClipRef>{...state.hidden}..remove(clip),
      ),
    );
  }

  /// [clip] was marked private while shown: covered with its caption.
  void cover(ClipRef clip) {
    if (state.hidden.contains(clip) && !state.revealed.contains(clip)) return;
    emit(
      state.copyWith(
        revealed: <ClipRef>{...state.revealed}..remove(clip),
        hidden: <ClipRef>{...state.hidden, clip},
      ),
    );
  }

  void _show(ClipRef? clip) {
    if (clip != null) emit(_showing(state, clip));
  }

  ViewerState _showing(ViewerState from, ClipRef clip) => from.copyWith(
    clip: clip,
    caption: _captions.of(clip),
    step: _isAfter(clip, from.clip) ? ViewerStep.forward : ViewerStep.backward,
  );

  static bool _isAfter(ClipRef clip, ClipRef other) => clip.day == other.day
      ? clip.ordinal > other.ordinal
      : clip.day.isAfter(other.day);

  /// A newer snapshot: the clip shown may have gone (deleted here or
  /// elsewhere), or been rewritten (a subtitle edit: its caption).
  void _indexChanged(ClipIndex index) {
    if (identical(index, state.index)) return;
    final ViewerState next = state.copyWith(
      index: index,
      filteredIndex: _filtering.of(index, state.filter),
    );
    if (index.stampOf(state.clip) != null) {
      emit(next.copyWith(caption: _captions.of(state.clip)));
      return;
    }
    final ClipRef? after = next.next ?? next.previous;
    emit(after == null ? next.copyWith(closed: true) : _showing(next, after));
  }

  static Profile _profileOf(ClipRef clip, ProfilesRepository profiles) =>
      profiles.profiles.firstWhere(
        (Profile profile) => profile.key == clip.profile,
        orElse: () => profiles.active,
      );

  @override
  Future<void> close() async {
    await Future.wait<void>(<Future<void>>[
      _clipChanges.cancel(),
      _soundChanges.cancel(),
    ]);
    return super.close();
  }
}
