import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/policy/transition_policy.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/movie_music.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/platform/audio_picker_gateway.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/free_space_gateway.dart';
import 'package:one_second_diary/core/storage/storage_budget.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_backfill.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/movies/domain/clip_picks.dart';
import 'package:one_second_diary/features/movies/domain/date_choice.dart';
import 'package:one_second_diary/features/movies/domain/movie_clip_facts.dart';
import 'package:one_second_diary/features/movies/domain/movie_draft.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/domain/movie_rules.dart';
import 'package:one_second_diary/features/movies/domain/movie_selection.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/domain/movie_space.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_event.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_state.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// The state the Create movie screens share, scoped to the flow: the router's
/// flow `ShellRoute` creates one when the flow opens and closes it when the
/// flow is left, so every flow screen reads the same one.
class CreateMovieCubit extends Cubit<CreateMovieState> {
  /// [preset] is the range the flow opens on, picked as if the user had;
  /// without, the default follows the clips.
  CreateMovieCubit({
    MovieSource? source,
    MoviePreset? preset,
    TagFilter? tags,
    required this._profiles,
    required this._clips,
    required Clock clock,
    required this._freeSpace,
    required this._backfill,
    this._metadata,
    this._audioPicker,
  }) : super(
         _opened(_profiles, clock, source: source, preset: preset, tags: tags),
       ) {
    _follow(state.profile);
    _progress = _backfill.progress.listen((_) => _reading());
    unawaited(_awaitIdle());
  }

  final ProfilesRepository _profiles;
  final ClipRepository _clips;
  final FreeSpaceGateway _freeSpace;
  final ClipMetadataBackfill _backfill;

  /// The clips' cached facts, for the transition counts; without it every
  /// clip counts as not read yet.
  final ClipMetadataCache? _metadata;

  /// The system picker for music files; without it "Add music files"
  /// adds nothing.
  final AudioPickerGateway? _audioPicker;

  /// Whether the picker is open.
  bool _picking = false;
  StreamSubscription<ClipIndex>? _index;
  StreamSubscription<void>? _progress;

  /// Whether the backfill's end is being awaited.
  bool _awaitingIdle = false;

  /// The state the flow opens with: [tags] when given, else what a range
  /// [source] carries; the source carries whichever applies.
  static CreateMovieState _opened(
    ProfilesRepository profiles,
    Clock clock, {
    required MovieSource? source,
    required MoviePreset? preset,
    required TagFilter? tags,
  }) {
    final TagFilter filter = switch ((tags, source)) {
      (final TagFilter tags, _) when tags.isNotEmpty => tags,
      (_, final RangedMovieSource ranged) => ranged.tags,
      _ => TagFilter.none,
    };
    return CreateMovieState(
      profile: profiles.active.key,
      today: LocalDay.fromDateTime(clock.now()),
      tags: filter,
      source: source is RangedMovieSource ? source.withTags(filter) : source,
      preset: preset ?? MoviePreset.thisMonth,
      presetChosen: preset != null,
    );
  }

  /// The default when "This month" has too few clips, in order.
  static const List<MoviePreset> _defaults = <MoviePreset>[
    MoviePreset.thisMonth,
    MoviePreset.last30Days,
    MoviePreset.thisYear,
    MoviePreset.allTime,
  ];

  /// Closes at once: the subscription's cancel may complete only when the
  /// repository's zone runs, and the flow must be closed when it is left.
  @override
  Future<void> close() {
    unawaited(_index?.cancel());
    unawaited(_progress?.cancel());
    return super.close();
  }

  /// "Try again" on a diary that could not be read: reads the flow profile's
  /// folder again; the watch shows its clips, or says again that it can't be
  /// read (`ClipRepository` logged why).
  Future<void> readAgain() async {
    if (state.status != CreateMovieStatus.failed) return;
    final ProfileKey profile = state.profile;
    emit(state.copyWith(status: CreateMovieStatus.loading));
    try {
      final ClipIndex index = await _clips.rescan(profile);
      if (!isClosed && state.profile == profile) _show(index);
    } on AppException {
      if (!isClosed && state.profile == profile) _failed();
    }
  }

  /// The user picks [preset]; the count follows at once.
  void choosePreset(MoviePreset preset) =>
      emit(state.copyWith(preset: preset, presetChosen: true));

  /// The profile chip: the movie is made of [profile]'s clips. The app's active
  /// profile does not change.
  void chooseProfile(ProfileKey profile) {
    if (profile == state.profile) return;
    emit(
      CreateMovieState(
        profile: profile,
        today: state.today,
        isReadingClips: state.isReadingClips,
        preset: state.preset,
        presetChosen: state.presetChosen,
        source: switch (state.source) {
          final RangedMovieSource range => range.withTags(TagFilter.none),
          _ => null,
        },
      ),
    );
    _follow(profile);
  }

  /// "Only videos tagged…": the ranges and the picker keep the clips tagged one
  /// of [tags] (every clip when empty).
  void setOnlyTags(Set<String> tags) {
    final TagFilter only = TagFilter(anyOf: tags);
    _retag(
      TagFilter(
        anyOf: tags,
        noneOf: state.tags.noneOf
            .where((String tag) => !only.includes(tag))
            .toSet(),
      ),
    );
  }

  /// "Leave out videos tagged…": the ranges and the picker drop the clips
  /// tagged one of [tags]. A tag chosen here leaves "only tagged".
  void setWithoutTags(Set<String> tags) {
    final TagFilter without = TagFilter(noneOf: tags);
    _retag(
      TagFilter(
        anyOf: state.tags.anyOf
            .where((String tag) => !without.excludes(tag))
            .toSet(),
        noneOf: tags,
      ),
    );
  }

  /// The × on a chosen tag's chip: [tag] leaves whichever list it is in.
  void removeTag(String tag) => _retag(
    state.tags.includes(tag)
        ? state.tags.toggleAny(tag)
        : state.tags.excludes(tag)
        ? state.tags.toggleNone(tag)
        : state.tags,
  );

  /// Every clip again.
  void clearTags() => _retag(TagFilter.none);

  /// The movie's filter is [tags]: every count follows, the source carries it,
  /// the movie is another one, and the default range follows the clips again
  /// unless the user picked one.
  void _retag(TagFilter tags) {
    if (tags == state.tags) return;
    final MovieSource? source = state.source;
    final CreateMovieState next = state.copyWith(
      tags: tags,
      source: source is RangedMovieSource ? source.withTags(tags) : source,
    );
    emit(
      _redrafted(
        next.presetChosen ? next : next.copyWith(preset: _defaultPreset(next)),
      ),
    );
  }

  /// The movie is made of the range picked.
  void confirmPreset() => _choose(MovieSource.preset(state.preset));

  /// The month sheet opens: on the month of the preset's range when it is one
  /// month a movie can be made of ("This month"), else on the latest such
  /// month.
  void openMonthPicker() {
    final LocalDay today = state.today;
    final bool thisMonth =
        state.preset == MoviePreset.thisMonth &&
        state.isOpen(today.year, today.month);
    emit(
      state.copyWith(
        monthChoice: thisMonth
            ? MonthChoice(year: today.year, month: today.month)
            : _latestOpenMonth(),
      ),
    );
  }

  /// The year stepper: shows [year] (from the first recorded year to this
  /// year).
  void showYear(int year) {
    if (year < state.firstYear || year > state.today.year) return;
    final int? month = state.monthChoice?.month;
    emit(
      state.copyWith(
        monthChoice: MonthChoice(
          year: year,
          month: month != null && state.isOpen(year, month)
              ? month
              : _latestOpenMonthOf(year),
        ),
      ),
    );
  }

  /// Picks [month] of the year shown, when a movie can be made of it.
  void pickMonth(int month) {
    final int year = state.monthChoice?.year ?? state.today.year;
    if (!state.isOpen(year, month)) return;
    emit(
      state.copyWith(
        monthChoice: MonthChoice(year: year, month: month),
      ),
    );
  }

  /// The movie is made of the month picked.
  void confirmMonth() {
    final MonthChoice? choice = state.monthChoice;
    final int? month = choice?.month;
    if (choice == null || month == null) return;
    _choose(MovieSource.month(year: choice.year, month: month));
  }

  /// The dates sheet opens: on the month of the last day picked before, or this
  /// month. A first day picked without a last starts over.
  void openDatePicker() {
    if (state.pickableDays == null) return;
    final DayRange? kept = state.dateChoice?.range;
    emit(
      state.copyWith(
        dateChoice: DateChoice(
          from: kept?.first,
          to: kept?.last,
          shown: DiaryMonth.of(kept?.last ?? state.today),
        ),
      ),
    );
  }

  /// A tap on [day] in the dates sheet: the first tap picks the first day, the
  /// next the last (the same day makes a one-day range).
  void pickDay(LocalDay day) {
    final DateChoice? choice = state.dateChoice;
    if (choice == null || !state.isPickable(day)) return;
    final LocalDay? from = choice.from;
    emit(
      state.copyWith(
        dateChoice: switch (choice) {
          _ when from == null || day.isBefore(from) => choice.copyWith(
            from: day,
          ),
          DateChoice(to: null) => choice.copyWith(to: day),
          _ => choice.copyWith(from: day, clearTo: true),
        },
      ),
    );
  }

  /// The From field: the next tap picks the first day again (the last
  /// goes with it).
  void restartDates() {
    final DateChoice? choice = state.dateChoice;
    if (choice == null || choice.from == null) return;
    emit(state.copyWith(dateChoice: choice.copyWith(clearFrom: true)));
  }

  /// The To field: the next tap picks the last day again.
  void repickEndDate() {
    final DateChoice? choice = state.dateChoice;
    if (choice == null || choice.to == null) return;
    emit(state.copyWith(dateChoice: choice.copyWith(clearTo: true)));
  }

  /// The dates sheet shows the month before, back to the first recorded
  /// day's.
  void showPreviousMonth() {
    final DateChoice? choice = state.dateChoice;
    if (choice == null || !state.canShowPreviousDateMonth) return;
    emit(
      state.copyWith(dateChoice: choice.copyWith(shown: choice.shown.previous)),
    );
  }

  /// The dates sheet shows the month after, up to this month.
  void showNextMonth() {
    final DateChoice? choice = state.dateChoice;
    if (choice == null || !state.canShowNextDateMonth) return;
    emit(state.copyWith(dateChoice: choice.copyWith(shown: choice.shown.next)));
  }

  /// The movie is made of the days picked, when they hold enough clips.
  void confirmDates() {
    final DayRange? range = state.dateChoice?.range;
    if (range == null || !state.canConfirmDates) return;
    _choose(MovieSource.dateRange(range));
  }

  /// Picks [clip], or unpicks it when it was. An unreadable clip is never
  /// picked.
  void togglePick(ClipRef clip) {
    if (state.unavailable.contains(clip)) return;
    emit(state.copyWith(picks: state.picks.toggle(clip)));
  }

  /// "Select all": picks every clip the picker shows (through the tag filter)
  /// that is neither private nor known to be unreadable (a private or hidden
  /// clip picked by hand stays picked), or unpicks every clip when they all
  /// are.
  void toggleAll() {
    final ClipIndex? selectable = state.selectable;
    if (selectable == null) return;
    emit(
      state.copyWith(
        picks: state.allPicked
            ? const ClipPicks.none()
            : state.picks.adding(
                selectable.newestFirst.where(
                  (ClipRef clip) => !state.unavailable.contains(clip),
                ),
              ),
      ),
    );
  }

  /// [clip]'s picture could not be read (a missing or corrupt file), or can
  /// again ([unavailable] false).
  void setUnavailable(ClipRef clip, {required bool unavailable}) {
    if (state.unavailable.contains(clip) == unavailable) return;
    emit(
      state.copyWith(
        unavailable: Set<ClipRef>.unmodifiable(
          unavailable
              ? <ClipRef>{...state.unavailable, clip}
              : state.unavailable.difference(<ClipRef>{clip}),
        ),
        picks: unavailable ? state.picks.removing(<ClipRef>[clip]) : null,
      ),
    );
  }

  /// The confirmation's switch: the range takes the profile's private clips
  /// too, or leaves them out again.
  void setIncludePrivate({required bool include}) {
    if (include == state.includePrivate) return;
    emit(_redrafted(state.copyWith(includePrivate: include)));
  }

  /// The confirmation's "Transition": [transition] between the clips, or null
  /// for hard cuts.
  void setTransition(MovieTransition? transition) {
    if (transition == state.transition) return;
    emit(
      _counted(
        state.copyWith(
          transition: transition,
          clearTransition: transition == null,
          upgradeOlderClips: false,
          launch: MovieLaunch.idle,
        ),
      ),
    );
  }

  /// "Also apply to older clips": with a transition, whether the clips
  /// that cannot be cut at a keyframe are re-encoded first.
  void setUpgradeOlderClips({required bool upgrade}) {
    if (upgrade == state.upgradeOlderClips) return;
    emit(state.copyWith(upgradeOlderClips: upgrade, launch: MovieLaunch.idle));
  }

  /// "Add music files": opens the system picker and appends what was picked to
  /// the movie's music (made now, at the default volume, when there was none).
  Future<bool> addMusic() async {
    final AudioPickerGateway? picker = _audioPicker;
    if (picker == null || _picking) return false;
    _picking = true;
    final List<PickedAudio> picked;
    try {
      picked = await picker.pickAudio();
    } finally {
      _picking = false;
    }
    if (isClosed || picked.isEmpty) return false;
    final MovieMusic current =
        state.music ?? const MovieMusic(tracks: <String>[]);
    emit(
      state.copyWith(
        music: current.copyWith(
          tracks: List<String>.unmodifiable(<String>[
            ...current.tracks,
            for (final PickedAudio file in picked) file.path,
          ]),
        ),
        musicNames: Map<String, String>.unmodifiable(<String, String>{
          ...state.musicNames,
          for (final PickedAudio file in picked) file.path: file.name,
        }),
        launch: MovieLaunch.idle,
      ),
    );
    return true;
  }

  /// Removes track [index] of the music; the last one removed clears the
  /// music altogether.
  void removeMusicTrack(int index) {
    final MovieMusic? music = state.music;
    if (music == null || index < 0 || index >= music.tracks.length) return;
    final String removed = music.tracks[index];
    final List<String> tracks = List<String>.of(music.tracks)..removeAt(index);
    emit(
      tracks.isEmpty
          ? state.copyWith(clearMusic: true, launch: MovieLaunch.idle)
          : state.copyWith(
              music: music.copyWith(tracks: List<String>.unmodifiable(tracks)),
              musicNames: Map<String, String>.unmodifiable(
                <String, String>{...state.musicNames}..remove(removed),
              ),
              launch: MovieLaunch.idle,
            ),
    );
  }

  /// The music's [volume], 0 to 1 (clamped).
  void setMusicVolume(double volume) {
    final MovieMusic? music = state.music;
    final double clamped = volume.clamp(0, 1).toDouble();
    if (music == null || music.volume == clamped) return;
    emit(
      state.copyWith(
        music: music.copyWith(volume: clamped),
        launch: MovieLaunch.idle,
      ),
    );
  }

  /// "Keep the videos' sound": whether it plays under the music.
  void setKeepClipSound({required bool keep}) {
    final MovieMusic? music = state.music;
    if (music == null || music.keepClipSound == keep) return;
    emit(
      state.copyWith(
        music: music.copyWith(keepClipSound: keep),
        launch: MovieLaunch.idle,
      ),
    );
  }

  /// No music: the row goes back to None.
  void clearMusic() {
    if (state.music == null) return;
    emit(state.copyWith(clearMusic: true, launch: MovieLaunch.idle));
  }

  /// The movie is made of the clips picked.
  void confirmPicks() {
    if (!state.canConfirmPicks) return;
    _choose(MovieSource.custom(Set<ClipRef>.unmodifiable(state.picks.clips)));
  }

  /// "Create movie", with the movie's [title] (the range title the confirmation
  /// shows, in the app language).
  Future<void> startMovie({required String title}) async {
    final MovieDraft? draft = state.draft;
    if (draft == null ||
        !draft.canMake ||
        state.launch == MovieLaunch.checking) {
      return;
    }
    emit(state.copyWith(launch: MovieLaunch.checking));
    final int? free = await _freeSpace.freeBytes();
    // Closed, or the movie changed while the phone answered.
    if (isClosed || !identical(state.draft, draft)) return;
    // The copies made first weigh their length at the movie's bitrate.
    final int? shortfall = MovieSpace.shortfall(
      needed: MovieSpace.neededFor(
        draft.clipBytes,
        normalisedBytes: state.foreignClips == 0
            ? null
            : StorageBudget.clipBytes(
                format: _profiles.formatOf(state.profile),
                durationMs: state.foreignDurationMs,
              ),
      ),
      free: free,
    );
    emit(
      shortfall != null
          ? state.copyWith(
              launch: MovieLaunch.noSpace,
              spaceShortfall: shortfall,
            )
          : state.copyWith(
              launch: MovieLaunch.ready,
              request: MovieJobRequest(
                source: draft.source,
                profile: state.profile,
                format: _profiles.formatOf(state.profile),
                title: title,
                clipBytes: draft.clipBytes,
                includePrivate: draft.includePrivate,
                transition: state.transition,
                upgradeOlderClips: state.upgradeOlderClips,
                music: state.music,
              ),
            ),
    );
  }

  /// The movie is made of [source] (a range through the flow's tag filter): the
  /// confirmation shows its draft.
  void _choose(MovieSource source) => emit(
    _redrafted(
      state.copyWith(
        source: source is RangedMovieSource
            ? source.withTags(state.tags)
            : source,
        clearTransition: true,
        upgradeOlderClips: false,
        clearMusic: true,
      ),
    ),
  );

  /// The latest month a movie can be made of, back to the first recorded
  /// year; this year with none picked when there is none.
  MonthChoice _latestOpenMonth() {
    for (int year = state.today.year; year >= state.firstYear; year--) {
      final int? month = _latestOpenMonthOf(year);
      if (month != null) return MonthChoice(year: year, month: month);
    }
    return MonthChoice(year: state.today.year);
  }

  int? _latestOpenMonthOf(int year) {
    for (int month = 12; month >= 1; month--) {
      if (state.isOpen(year, month)) return month;
    }
    return null;
  }

  /// Follows [profile]'s clips: at once from its snapshot in memory, then
  /// each new one.
  void _follow(ProfileKey profile) {
    unawaited(_index?.cancel());
    final ClipIndex? index = _clips.snapshotOf(profile);
    if (index != null) _show(index);
    _index = _clips
        .watch(profile)
        .listen(_show, onError: (Object _) => _failed());
  }

  /// Shows [index]: the counts follow it, and a clip picked by hand that
  /// is gone from it (deleted meanwhile) is unpicked.
  void _show(ClipIndex index) {
    // The watch repeats the snapshot the flow opened with.
    if (identical(index, state.index)) return;
    final CreateMovieState shown = state.copyWith(
      status: CreateMovieStatus.ready,
      index: index,
      picks: state.picks.where(
        (ClipRef clip) => index.clipsOn(clip.day).contains(clip),
      ),
      unavailable: Set<ClipRef>.unmodifiable(
        state.unavailable.where(
          (ClipRef clip) => index.clipsOn(clip.day).contains(clip),
        ),
      ),
    );
    emit(
      _redrafted(
        shown.presetChosen
            ? shown
            : shown.copyWith(preset: _defaultPreset(shown)),
      ),
    );
  }

  /// The backfill reads clips: a tag filter may miss some for now.
  void _reading() {
    if (!state.isReadingClips) emit(state.copyWith(isReadingClips: true));
    unawaited(_awaitIdle());
  }

  /// Once the backfill is idle, every clip's tags are known.
  Future<void> _awaitIdle() async {
    if (_awaitingIdle) return;
    _awaitingIdle = true;
    try {
      // A run that starts as one ends (an enqueue at the end of a drain)
      // is still reading: wait that one out too.
      do {
        await _backfill.whenIdle;
      } while (_backfill.isRunning && !isClosed);
    } finally {
      _awaitingIdle = false;
    }
    if (!isClosed && state.isReadingClips) {
      emit(_counted(state.copyWith(isReadingClips: false)));
    }
  }

  /// [next] with what the cache says of its draft's clips: with a transition,
  /// the clips whose cached keyframes say they cannot be cut and those with no
  /// cached keyframes (0 and 0 without one); always, the clips converted first
  /// (foreign, legacy, copied in) with their length, and the movie's length
  /// (clips not read count as the average read).
  CreateMovieState _counted(CreateMovieState next) {
    final MovieDraft? draft = next.draft;
    final ClipIndex? index = next.index;
    if (draft == null || index == null) {
      return next.copyWith(
        olderClips: 0,
        unreadClips: 0,
        foreignClips: 0,
        foreignDurationMs: 0,
        clearDraftDuration: true,
      );
    }
    final ClipFormat format = _profiles.formatOf(next.profile);
    int older = 0;
    int unread = 0;
    int foreign = 0;
    int foreignMs = 0;
    int read = 0;
    int readMs = 0;
    for (final ClipRef clip in draft.clips) {
      final FileStamp? stamp = index.stampOf(clip);
      final ClipMeta? meta = stamp == null
          ? null
          : _metadata?.lookup(relPath: clip.relPath, stamp: stamp);
      final ClipKeyframes? keyframes = meta?.keyframes;
      if (keyframes == null) {
        unread++;
      } else if (!TransitionPolicy.isReady(keyframes, fps: format.fps)) {
        older++;
      }
      final int? durationMs = meta?.durationMs;
      if (durationMs != null) {
        read++;
        readMs += durationMs;
      }
      if (MovieClipFacts.needsConverting(meta, format: format)) {
        foreign++;
        foreignMs += durationMs ?? 0;
      }
    }
    final bool withTransition = next.transition != null;
    return next.copyWith(
      olderClips: withTransition ? older : 0,
      unreadClips: withTransition ? unread : 0,
      foreignClips: foreign,
      foreignDurationMs: foreignMs,
      clearDraftDuration: read == 0,
      draftDurationMs: read == 0
          ? null
          : (readMs / read * draft.clips.length).round(),
    );
  }

  /// [next] with the draft of its source and clips, when both are known.
  CreateMovieState _redrafted(CreateMovieState next) {
    final MovieSource? source = next.source;
    final ClipIndex? index = next.index;
    if (source == null || index == null) return next;
    return _counted(
      next.copyWith(
        draft: MovieDraft.of(
          index,
          source,
          today: next.today,
          includePrivate: next.includePrivate,
        ),
        launch: MovieLaunch.idle,
      ),
    );
  }

  /// The diary could not be read (`ClipRepository` logged why).
  void _failed() {
    if (state.index == null) {
      emit(state.copyWith(status: CreateMovieStatus.failed));
    }
  }

  /// "This month", or the first range with enough clips for a movie, on
  /// [next]'s clips as its ranges count them (through its tag filter).
  MoviePreset _defaultPreset(CreateMovieState next) => _defaults.firstWhere(
    (MoviePreset preset) =>
        (next.rangeIndex?.countClipsFor(
              MovieSource.preset(preset),
              today: next.today,
              includePrivate: true,
            ) ??
            0) >=
        MovieRules.minClips,
    orElse: () => MoviePreset.thisMonth,
  );
}
