import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/domain/profiles_snapshot.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/today/domain/part_of_day.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_state.dart';

/// Today: the day, the active profile and the day's clips, for as long as
/// the Today tab lives.
///
/// - The day's clips are derived from the active profile's `ClipRepository`
///   snapshot, never stored: a clip filed under yesterday never makes
///   today done, and a clip saved, undone or deleted anywhere shows at
///   once. Several clips a day, in recording order.
/// - The day rolls over at local midnight (`MidnightTicker`), and the part
///   of the day the character greets by changes at 05:00, 12:00, 18:00 and
///   22:00; [refreshTime] catches both up when the app resumes.
/// - The profile's recorded days (and its latest one) ride along, for the
///   character's first-clip, milestone and welcome-back lines.
/// - It follows the active profile (`ProfilesRepository.watch()`): a switch
///   made anywhere shows that profile's shape and day. The profile chip
///   switches through `ProfilesCubit`, the app's profiles, which also
///   gives it the name and photo it shows.
class TodayCubit extends Cubit<TodayState> {
  TodayCubit({
    required this._clips,
    required ProfilesRepository profiles,
    required MidnightTicker midnight,
    required this._clock,
    required SettingsRepository settings,
    required this._logger,
  }) : super(
         TodayState(
           day: LocalDay.fromDateTime(_clock.now()),
           partOfDay: PartOfDay.at(_clock.now()),
           profile: profiles.active,
           stampFormat: settings.stampStyle.value.format,
         ),
       ) {
    _followClipsOf(state.profile.key);
    _profileChanges = profiles.watch().listen(_profilesChanged);
    _days = midnight.days.listen((_) => refreshTime());
    _stampStyles = settings.stampStyle.changes.listen(
      (StampStyle style) => emit(state.copyWith(stampFormat: style.format)),
    );
    _armPartOfDay();
  }

  final ClipRepository _clips;
  final Clock _clock;
  final AppLogger _logger;

  static const String _tag = 'TODAY';

  StreamSubscription<ClipIndex>? _clipChanges;
  late final StreamSubscription<ProfilesSnapshot> _profileChanges;
  late final StreamSubscription<LocalDay> _days;
  late final StreamSubscription<StampStyle> _stampStyles;

  /// Fires when the part of the day next changes.
  Timer? _partOfDayChange;

  /// The active profile's latest snapshot; null until its diary is read.
  ClipIndex? _index;

  /// Reads the clock again: the day (with its clips) and the part of the
  /// day. The midnight ticker and the part-of-day timer call it; the page
  /// calls it when the app resumes, because timers don't run while the
  /// phone sleeps.
  void refreshTime() {
    final DateTime now = _clock.now();
    emit(
      _withDayClips(
        state.copyWith(
          day: LocalDay.fromDateTime(now),
          partOfDay: PartOfDay.at(now),
        ),
      ),
    );
    _armPartOfDay();
  }

  /// Brings [clip], a clip of the day, into view: Edit acts on it.
  void showClip(ClipRef clip) => emit(state.withShownClip(clip));

  /// Another profile became active, or the active one changed (a rename,
  /// a new photo).
  void _profilesChanged(ProfilesSnapshot profiles) {
    final Profile active = profiles.active;
    if (active == state.profile) return;
    if (active.key == state.profile.key) {
      emit(state.copyWith(profile: active));
    } else {
      _followClipsOf(active.key, profile: active);
    }
  }

  /// Shows [key]'s day at once from the snapshot it already has (loading
  /// while it has none), then follows its changes. [profile] is the new
  /// active profile, when it changed.
  void _followClipsOf(ProfileKey key, {Profile? profile}) {
    unawaited(_clipChanges?.cancel());
    _index = _clips.snapshotOf(key);
    emit(
      _withDayClips(
        state.copyWith(
          profile: profile,
          status: _index == null ? TodayStatus.loading : null,
        ),
      ),
    );
    _clipChanges = _clips
        .watch(key)
        .listen(
          (ClipIndex index) {
            _index = index;
            emit(_withDayClips(state));
          },
          onError: (Object error, StackTrace stackTrace) {
            _logger.error(
              _tag,
              "Could not read today's clips of ${key.albumLabel}",
              error: error,
              stackTrace: stackTrace,
            );
            if (_index == null) {
              emit(state.copyWith(status: TodayStatus.unavailable));
            }
          },
        );
  }

  /// [next] with the clips of its day and the profile's recorded days,
  /// when the diary has been read. A clip new to the day comes into view.
  TodayState _withDayClips(TodayState next) {
    final ClipIndex? index = _index;
    if (index == null) {
      return next.withDiary(
        clips: const <ClipRef>[],
        recordedDays: 0,
        lastRecordedDay: null,
        status: next.status,
        shownClip: next.shownClip,
      );
    }
    final List<ClipRef> clips = index.clipsOn(next.day);
    final bool added = clips.any((ClipRef clip) => !state.clips.contains(clip));
    return next.withDiary(
      clips: clips,
      recordedDays: index.dayCount,
      lastRecordedDay: index.lastDay,
      status: TodayStatus.ready,
      shownClip: added ? null : next.shownClip,
    );
  }

  void _armPartOfDay() {
    _partOfDayChange?.cancel();
    final DateTime now = _clock.now();
    _partOfDayChange = Timer(
      PartOfDay.nextChangeAfter(now).difference(now),
      refreshTime,
    );
  }

  @override
  Future<void> close() async {
    _partOfDayChange?.cancel();
    await _days.cancel();
    await _stampStyles.cancel();
    await _profileChanges.cancel();
    await _clipChanges?.cancel();
    return super.close();
  }
}
