import 'dart:async';
import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/share_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/diary/data/clip_captions.dart';
import 'package:one_second_diary/features/diary/data/clip_filtering.dart';
import 'package:one_second_diary/features/diary/domain/clip_caption.dart';
import 'package:one_second_diary/features/diary/domain/clip_filter.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/diary_opener.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/domain/profiles_snapshot.dart';
import 'package:one_second_diary/features/settings/data/setting.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

/// The Diary tab's state, one per tab: the active profile's clips from the
/// `ClipRepository` snapshot, the month shown and the day selected.
///
/// Everything comes from memory: the first state is built from the
/// snapshot the launch already read, so the calendar's first frame is
/// complete. Every query is O(1) or O(log n) on the index, never O(clips).
///
/// It follows the active profile (a switch opens the new diary on this
/// month), that profile's snapshots (a clip saved or deleted anywhere
/// shows at once), midnight (today moves on) and the requests from
/// elsewhere for this month's calendar or one day ([DiaryOpener]).
///
/// The filter ([setFilter]) is applied once per snapshot and filter
/// ([ClipFiltering]); the state keeps the result, so the calendar, the
/// player, Memories and the viewer read one sub-index.
class DiaryCubit extends Cubit<DiaryState> {
  DiaryCubit({
    required ProfilesRepository profiles,
    required ClipRepository clips,
    required SettingsRepository settings,
    required MidnightTicker midnight,
    required this._captions,
    required this._filtering,
    required this._store,
    required this._share,
    required DiaryOpener opener,
    required this._paths,
    required this._logger,
  }) : _clips = clips,
       _settings = settings,
       super(
         _opening(profiles.active, clips, midnight.today)
             .withAlternativeColors(
               on: settings.useAlternativeCalendarColors.value,
             )
             .withAutoPlay(on: settings.calendarAutoPlay.value)
             // The view picked last, also after the app was closed.
             .withView(
               settings.diaryMemoriesView.value
                   ? DiaryView.memories
                   : DiaryView.calendar,
             ),
       ) {
    _followClipsOf(state.profile);
    _colourChanges = settings.useAlternativeCalendarColors.changes.listen(
      (bool on) => emit(state.withAlternativeColors(on: on)),
    );
    // A choice made elsewhere (the viewer) shows here too; the echoes of
    // this cubit's own writes are skipped, as a quick second tap has
    // already moved on.
    _soundChanges = settings.calendarAutoSound.changes.listen((bool on) {
      if (_writing.isEmpty) emit(state.withSound(on: on));
    });
    _autoPlayChanges = settings.calendarAutoPlay.changes.listen((bool on) {
      if (_writing.isEmpty) emit(state.withAutoPlay(on: on));
    });
    _profileChanges = profiles.watch().listen(_profilesChanged);
    _dayChanges = midnight.days.listen((LocalDay today) {
      emit(state.withToday(today));
    });
    // The Journey's "This month" and "Days recorded".
    _openRequests = opener.requests.listen((_) {
      showThisMonth();
      // A one-off: the view the user picked stays the remembered one.
      showView(DiaryView.calendar, remember: false);
    });
    // A place's clips: "Open day".
    _dayRequests = opener.dayRequests.listen(_openDay);
    final LocalDay? pending = opener.takePendingDay();
    if (pending != null) _openDay(pending);
  }

  void _openDay(LocalDay day) {
    showDay(day);
    showView(DiaryView.calendar, remember: false);
  }

  final ClipRepository _clips;
  final ClipCaptions _captions;
  final ClipFiltering _filtering;
  final ClipStore _store;
  final ShareGateway _share;
  final AppPaths _paths;
  final SettingsRepository _settings;
  final AppLogger _logger;

  static const String _tag = 'CALENDAR';

  /// The settings this cubit is storing right now.
  final List<Setting<bool>> _writing = <Setting<bool>>[];

  StreamSubscription<ClipIndex>? _clipChanges;
  late final StreamSubscription<ProfilesSnapshot> _profileChanges;
  late final StreamSubscription<LocalDay> _dayChanges;
  late final StreamSubscription<bool> _colourChanges;
  late final StreamSubscription<bool> _soundChanges;
  late final StreamSubscription<bool> _autoPlayChanges;
  late final StreamSubscription<void> _openRequests;
  late final StreamSubscription<LocalDay> _dayRequests;

  /// Shows the month before the one shown, down to [DiaryState.earliestMonth].
  void showPreviousMonth() {
    if (state.canShowPrevious) emit(state.opening(state.month.previous));
  }

  /// Shows the month after the one shown, up to this month.
  void showNextMonth() {
    if (state.canShowNext) emit(state.opening(state.month.next));
  }

  /// Back to this month and its default day (the tab reselected).
  void showThisMonth() => emit(state.opening(state.thisMonth));

  /// What [clip] says about itself (its subtitle and place), from memory:
  /// the caption row and the Memories cards read it while they build.
  ClipCaption captionOf(ClipRef clip) => _captions.of(clip);

  /// Shows [day] in its month, on its [clip] (else its first): a day opened
  /// from elsewhere, e.g. the clip the viewer showed last. It is a one-off
  /// selection, never remembered: the arrows, the tab and a later visit
  /// behave as usual. A day to come is ignored.
  void showDay(LocalDay day, {ClipRef? clip}) {
    if (!state.dayOf(day).isSelectable) return;
    emit(state.showing(DiaryMonth.of(day), selected: day, clip: clip));
  }

  /// Add video / Add photo started the add flow for the selected day.
  void addStarted() => emit(state.withAdding(adding: true));

  /// The add flow ended, with the clip [saved] (its day then shows, on that
  /// clip; a filter is cleared, so the new clip shows whatever its tags),
  /// or without one (the user gave up, or it did not work out).
  void addFinished({ClipRef? saved}) {
    final DiaryState done = state.withAdding(adding: false);
    emit(
      saved == null
          ? done
          : _filtered(done, const ClipFilter.none()).showing(
              DiaryMonth.of(saved.day),
              selected: saved.day,
              clip: saved,
            ),
    );
  }

  /// Filters the Diary to the clips [filter] keeps (the filter sheet, live
  /// as the user picks): days without one dim, the player, Memories and
  /// the viewer step through the kept clips only. A selected day the
  /// filter leaves out gives way to the month's default day. Session-only.
  void setFilter(ClipFilter filter) {
    if (filter == state.filter) return;
    emit(_reselected(_filtered(state, filter)));
  }

  /// "Clear filter".
  void clearFilter() => setFilter(const ClipFilter.none());

  /// [state] under [filter], its kept clips computed once.
  DiaryState _filtered(DiaryState state, ClipFilter filter) {
    final ClipIndex? index = state.index;
    return state.withFilter(
      filter,
      filtered: index == null ? null : _filtering.of(index, filter),
    );
  }

  /// [state] with its selection still allowed under its filter, else on
  /// the month's default day.
  DiaryState _reselected(DiaryState state) {
    final LocalDay? selected = state.selected;
    if (selected == null || state.dayOf(selected).isSelectable) return state;
    return state.opening(state.month);
  }

  /// Deletes [clip], from the gallery and the index
  /// (`ClipStore.delete`, which also removes a file the media store never
  /// knew); the trash then forgets its backup. The state says it runs,
  /// then whether it worked, every time (the snackbar listens). The day
  /// follows the index: it turns missed, or shows its next clip.
  Future<void> deleteClip(ClipRef clip) async {
    emit(state.withDeletion(ClipDeletion.deleting, clip: clip));
    try {
      // The "Video deleted" snackbar offers Undo, and makes the delete
      // final when it leaves (`DeletedClipSnackbar`).
      await _store.delete(clip);
      _logger.info(_tag, 'Deleted ${clip.relPath}');
      emit(state.withDeletion(ClipDeletion.deleted, clip: clip));
    } on Exception catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not delete ${clip.relPath}',
        error: error,
        stackTrace: stackTrace,
      );
      emit(state.withDeletion(ClipDeletion.failed, clip: clip));
    }
  }

  /// Opens the system share sheet on [clip]'s file as it is stored (its
  /// burned stamp, its subtitles), anchored at [origin] (iPad): Memories'
  /// long press.
  Future<void> shareClip(ClipRef clip, {Rect? origin}) => _share.shareFiles(
    <String>[_paths.absoluteFromVideos(clip.relPath)],
    origin: origin,
  );

  /// Shows the clip at [position] of the selected day (the player paged).
  void showClipAt(int position) => emit(state.showingClipAt(position));

  /// The sound toggle: turns the player's sound on or off, and remembers
  /// the choice (`calendarAutoSound`, only ever written by the user; the
  /// viewer opens with it).
  Future<void> toggleSound() async {
    final bool on = state.muted;
    emit(state.withSound(on: on));
    await _remember(_settings.calendarAutoSound, value: on, what: 'sound');
  }

  /// The user played or paused the clip: remembered as whether the next
  /// clip plays on its own (`calendarAutoPlay`). A pause the app makes (a
  /// hidden tab, a sheet) is never remembered.
  Future<void> playbackChosen({required bool playing}) async {
    emit(state.withAutoPlay(on: playing));
    await _remember(
      _settings.calendarAutoPlay,
      value: playing,
      what: 'autoplay',
    );
  }

  /// Stores [value] in [setting]; a refusal keeps the choice for this
  /// session and is logged.
  Future<void> _remember(
    Setting<bool> setting, {
    required bool value,
    required String what,
  }) async {
    _writing.add(setting);
    try {
      await setting.set(value);
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not remember the player\'s $what choice',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _writing.remove(setting);
    }
  }

  /// The viewer is about to open from [origin], whose clip flies there
  /// and back; the Diary holds still under it.
  void viewerOpening(ViewerOrigin origin) =>
      emit(state.withViewerOpenFrom(origin));

  /// The viewer closed: the Diary plays on.
  void viewerClosed() => emit(state.withViewerClosed);

  /// The player's private [clip] was uncovered (its tap): its caption
  /// shows with its picture.
  void revealClip(ClipRef clip) {
    if (state.revealed != clip) emit(state.withRevealed(clip));
  }

  /// [clip] was marked private while it played: covered with its caption.
  void coverClip(ClipRef clip) {
    if (state.revealed == clip) emit(state.withoutRevealed);
  }

  /// "Try again" on a diary whose folder could not be read: it loads, then
  /// shows the diary, or says again that it can't be read (logged by the
  /// `ClipRepository`).
  Future<void> readAgain() async {
    final ProfileKey profile = state.profile.key;
    emit(state.readingAgain);
    try {
      final ClipIndex index = await _clips.rescan(profile);
      if (!isClosed && state.profile.key == profile) _indexChanged(index);
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'The diary still can\'t be read',
        error: error,
        stackTrace: stackTrace,
      );
      if (!isClosed && state.index == null) emit(state.asUnreadable);
    }
  }

  /// Shows the calendar or Memories. The user's pick (the title row's
  /// toggle) is remembered, and the Diary opens in it next time, also
  /// after the app was closed; [remember] false is a one-off (the Journey
  /// opening this month's calendar). A refused write is logged; this
  /// session keeps the view.
  void showView(DiaryView view, {bool remember = true}) {
    emit(state.withView(view));
    if (remember) unawaited(_rememberView(view));
  }

  Future<void> _rememberView(DiaryView view) async {
    try {
      await _settings.diaryMemoriesView.set(view == DiaryView.memories);
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not remember the Diary\'s view',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Selects [day], showing its month. A day to come, or any day before
  /// the diary has been read, can't be selected.
  void selectDay(LocalDay day) {
    if (!state.dayOf(day).isSelectable) return;
    emit(state.showing(DiaryMonth.of(day), selected: day));
  }

  void _profilesChanged(ProfilesSnapshot snapshot) {
    final Profile active = snapshot.active;
    if (active.key == state.profile.key) return;
    _followClipsOf(active);
    emit(
      _opening(active, _clips, state.today)
          .withAlternativeColors(on: state.alternativeColors)
          .withView(state.view)
          .withAutoPlay(on: state.autoPlay)
          .withSound(on: !state.muted),
    );
  }

  void _followClipsOf(Profile profile) {
    unawaited(_clipChanges?.cancel());
    _clipChanges = _clips
        .watch(profile.key)
        .listen(
          _indexChanged,
          // The repository logs the failure; the calendar says it.
          onError: (Object _) => emit(state.asUnreadable),
        );
  }

  void _indexChanged(ClipIndex index) {
    if (identical(index, state.index)) return;
    final bool firstRead = state.index == null;
    final DiaryState next = state.withIndex(
      index,
      filtered: _filtering.of(index, state.filter),
    );
    emit(firstRead ? next.opening(next.month) : _reselected(next));
  }

  @override
  Future<void> close() async {
    // Every cancel starts at once: the midnight timer stops with the tab.
    await Future.wait<void>(<Future<void>>[
      ?_clipChanges?.cancel(),
      _profileChanges.cancel(),
      _dayChanges.cancel(),
      _colourChanges.cancel(),
      _soundChanges.cancel(),
      _autoPlayChanges.cancel(),
      _openRequests.cancel(),
      _dayRequests.cancel(),
    ]);
    return super.close();
  }

  static DiaryState _opening(
    Profile profile,
    ClipRepository clips,
    LocalDay today,
  ) => DiaryState(
    profile: profile,
    index: clips.snapshotOf(profile.key),
    today: today,
    month: DiaryMonth.of(today),
  ).opening(DiaryMonth.of(today));
}
