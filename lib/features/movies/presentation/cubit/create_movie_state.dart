import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/movie_music.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/movies/domain/clip_picks.dart';
import 'package:one_second_diary/features/movies/domain/date_choice.dart';
import 'package:one_second_diary/features/movies/domain/movie_draft.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/domain/movie_rules.dart';
import 'package:one_second_diary/features/movies/domain/movie_selection.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_event.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Whether the flow's profile's clips are known.
enum CreateMovieStatus {
  /// Its diary has not been read yet.
  loading,

  /// [CreateMovieState.index] holds its clips.
  ready,

  /// Its diary could not be read: no clips to make a movie of.
  failed,
}

/// Where the confirmation's "Create movie" is.
enum MovieLaunch {
  /// Not tapped yet, or the movie changed since.
  idle,

  /// Tapped: the free space is being checked.
  checking,

  /// The phone lacks [CreateMovieState.spaceShortfall] bytes: nothing
  /// started.
  noSpace,

  /// The movie may start: the page hands [CreateMovieState.request] to the
  /// movie job and opens the making page.
  ready,
}

/// The month sheet's choice: the year shown and the month picked in it
/// (1–12; null when that year has no month a movie can be made of).
final class MonthChoice extends Equatable {
  const MonthChoice({required this.year, this.month});

  final int year;
  final int? month;

  @override
  List<Object?> get props => <Object?>[year, month];
}

/// The Create movie flow, shared by every flow screen.
final class CreateMovieState extends Equatable {
  /// [pickIndex] is [index] through [tags] when the caller already has it
  /// (`copyWith` carries it while neither changes); made here otherwise.
  CreateMovieState({
    required this.profile,
    required this.today,
    this.status = CreateMovieStatus.loading,
    this.index,
    TagFilter? tags,
    ClipIndex? pickIndex,
    this.isReadingClips = true,
    this.preset = MoviePreset.thisMonth,
    this.presetChosen = false,
    this.source,
    this.monthChoice,
    this.dateChoice,
    this.picks = const ClipPicks.none(),
    this.unavailable = const <ClipRef>{},
    this.includePrivate = false,
    this.transition,
    this.upgradeOlderClips = false,
    this.olderClips = 0,
    this.unreadClips = 0,
    this.foreignClips = 0,
    this.foreignDurationMs = 0,
    this.draftDurationMs,
    this.music,
    this.musicNames = const <String, String>{},
    this.draft,
    this.launch = MovieLaunch.idle,
    this.spaceShortfall,
    this.request,
  }) : tags = tags ?? TagFilter.none,
       pickIndex = pickIndex ?? index?.filtered(tags ?? TagFilter.none);

  /// The profile the movie is made of. It starts as the app's active
  /// profile; the chip changes it for this movie only.
  final ProfileKey profile;

  /// The day the ranges end on.
  final LocalDay today;

  final CreateMovieStatus status;

  /// [profile]'s clips; null while [CreateMovieStatus.loading].
  final ClipIndex? index;

  /// The tag filter of the movie: "only videos tagged…" and "leave out videos
  /// tagged…". Every count and range follows it, and the source carries it.
  final TagFilter tags;

  /// [index] through [tags] (that very snapshot without a filter): what the
  /// picker shows, and the index every range is counted on.
  final ClipIndex? pickIndex;

  /// Whether the clips' metadata is still being read (the backfill runs): a
  /// clip not read yet is unknown to [tags], so a filtered count may still
  /// change.
  final bool isReadingClips;

  final MoviePreset preset;

  /// Whether the user picked [preset] (the default then stops following
  /// the clips).
  final bool presetChosen;

  /// The clips the flow will make a movie of: the Diary's month, or what a
  /// preset, the month sheet or the picker chose; null until then.
  final MovieSource? source;

  /// The month sheet's year and month; null until "Choose a month" opens.
  final MonthChoice? monthChoice;

  /// The dates sheet's days and month; null until "Choose dates" opens.
  final DateChoice? dateChoice;

  /// The clips picked by hand, kept while the flow is open, so coming back
  /// to the picker finds them picked.
  final ClipPicks picks;

  /// The clips the picker found unreadable (their picture could not be
  /// read): never picked.
  final Set<ClipRef> unavailable;

  /// Whether a range takes the profile's private clips too (the confirmation's
  /// switch).
  final bool includePrivate;

  /// The transition between clips (the confirmation's row); null, hard cuts,
  /// whenever the flow opens, changes profile or chooses another movie: never
  /// remembered.
  final MovieTransition? transition;

  /// With [transition], whether the clips that cannot be cut at a keyframe
  /// are re-encoded first (the row's switch). Off with every new draft.
  final bool upgradeOlderClips;

  /// With [transition], how many of the draft's clips the cache knows cannot be
  /// cut at a keyframe (saved before 2.1): they join with a hard cut unless
  /// [upgradeOlderClips]. 0 without a transition.
  final int olderClips;

  /// With [transition], how many of the draft's clips have no cached keyframes
  /// yet (not read, or read before 2.1): the engine reads them when the movie
  /// is made. 0 without a transition.
  final int unreadClips;

  /// How many of the draft's clips the cache says are converted first (foreign,
  /// legacy or copied in: `MovieClipFacts.needsConverting`), and their summed
  /// length, for "12 videos will be converted first (about 4 min)". 0 while
  /// nothing is read.
  final int foreignClips;
  final int foreignDurationMs;

  /// The movie's length from the cached facts: clips not read yet count as the
  /// average read clip; null until any clip of the draft is read.
  final int? draftDurationMs;

  /// The movie's music (the confirmation's row): the files picked, the volume
  /// and whether the videos' sound stays; null for none (the default).
  final MovieMusic? music;

  /// The name of each music file as the user knows it (`song.mp3`), by the
  /// path the app keeps it under; what the sheet shows.
  final Map<String, String> musicNames;

  /// The movie of [source] from [profile]'s clips; null until a source is
  /// chosen and the clips are read.
  final MovieDraft? draft;

  final MovieLaunch launch;

  /// The bytes to free before the movie fits ([MovieLaunch.noSpace]).
  final int? spaceShortfall;

  /// The movie to make ([MovieLaunch.ready]).
  final MovieJobRequest? request;

  /// [index] as a movie of a range sees it: through [tags], then without
  /// the private clips, unless [includePrivate].
  ClipIndex? get rangeIndex =>
      includePrivate ? pickIndex : pickIndex?.shareable;

  /// The clips [preset] finds: two binary searches.
  int get presetClips => _rangeClips(MovieSource.preset(preset));

  /// The clips a movie of [source] (a range) takes, on [rangeIndex], which
  /// already applied the filter and the privacy: two binary searches.
  int _rangeClips(MovieSource source) =>
      rangeIndex?.countClipsFor(source, today: today, includePrivate: true) ??
      0;

  /// Whether a movie can be made of [preset].
  bool get canContinue =>
      status == CreateMovieStatus.ready && presetClips >= MovieRules.minClips;

  /// Whether a movie can be made of [year]-[month].
  bool isOpen(int year, int month) {
    if (index == null || _isFuture(year, month)) return false;
    return _rangeClips(MovieSource.month(year: year, month: month)) >=
        MovieRules.minClips;
  }

  /// The first year the month sheet offers: the first recorded one.
  int get firstYear {
    final int? first = index?.firstDay?.year;
    return first == null || first > today.year ? today.year : first;
  }

  bool get canShowPreviousYear => (monthChoice?.year ?? today.year) > firstYear;

  bool get canShowNextYear => (monthChoice?.year ?? today.year) < today.year;

  /// The days "Choose dates" offers: the first day with a clip the movie may
  /// take (through [tags]; private clips aside, unless included) through today.
  DayRange? get pickableDays {
    final LocalDay? first = rangeIndex?.firstDay;
    return first == null ? null : DayRange(first: first, last: today);
  }

  /// Whether [day] is one of [pickableDays].
  bool isPickable(LocalDay day) {
    final DayRange? days = pickableDays;
    return days != null && !day.isBefore(days.first) && !day.isAfter(days.last);
  }

  /// The clips of the days picked (none until both days are): two binary
  /// searches, without the private clips unless [includePrivate].
  int get dateRangeClips {
    final DayRange? range = dateChoice?.range;
    return range == null ? 0 : rangeIndex?.countClipsIn(range) ?? 0;
  }

  /// Whether a movie can be made of the days picked.
  bool get canConfirmDates => dateRangeClips >= MovieRules.minClips;

  /// The first month the dates sheet shows: the first day's of
  /// [pickableDays].
  DiaryMonth get firstDateMonth {
    final LocalDay? first = pickableDays?.first;
    return first == null || first.isAfter(today)
        ? DiaryMonth.of(today)
        : DiaryMonth.of(first);
  }

  bool get canShowPreviousDateMonth =>
      (dateChoice?.shown ?? DiaryMonth.of(today)).isAfter(firstDateMonth);

  bool get canShowNextDateMonth => (dateChoice?.shown ?? DiaryMonth.of(today))
      .isBefore(DiaryMonth.of(today));

  bool get canConfirmPicks => picks.count >= MovieRules.minClips;

  /// The clips "Select all" picks: those the picker shows (through [tags]) that
  /// are not private.
  ClipIndex? get selectable => pickIndex?.shareable;

  /// Whether every clip "Select all" picks is picked ("Deselect all"),
  /// among those that can be read.
  bool get allPicked {
    final ClipIndex? index = this.index;
    final ClipIndex? selectable = this.selectable;
    if (index == null || selectable == null || picks.count == 0) return false;
    if (identical(selectable, index)) {
      return picks.count == index.clipCount - unavailable.length;
    }
    bool shown(ClipRef clip) => selectable.clipsOn(clip.day).contains(clip);
    final int picked = picks.clips.where(shown).length;
    return picked > 0 &&
        picked == selectable.clipCount - unavailable.where(shown).length;
  }

  bool _isFuture(int year, int month) =>
      year > today.year || (year == today.year && month > today.month);

  CreateMovieState copyWith({
    ProfileKey? profile,
    CreateMovieStatus? status,
    ClipIndex? index,
    TagFilter? tags,
    bool? isReadingClips,
    MoviePreset? preset,
    bool? presetChosen,
    MovieSource? source,
    MonthChoice? monthChoice,
    DateChoice? dateChoice,
    bool clearDateChoice = false,
    ClipPicks? picks,
    Set<ClipRef>? unavailable,
    bool? includePrivate,
    MovieTransition? transition,
    bool clearTransition = false,
    bool? upgradeOlderClips,
    int? olderClips,
    int? unreadClips,
    int? foreignClips,
    int? foreignDurationMs,
    int? draftDurationMs,
    bool clearDraftDuration = false,
    MovieMusic? music,
    bool clearMusic = false,
    Map<String, String>? musicNames,
    MovieDraft? draft,
    MovieLaunch? launch,
    int? spaceShortfall,
    MovieJobRequest? request,
  }) {
    final ClipIndex? nextIndex = index ?? this.index;
    final TagFilter nextTags = tags ?? this.tags;
    return CreateMovieState(
      profile: profile ?? this.profile,
      today: today,
      status: status ?? this.status,
      index: nextIndex,
      tags: nextTags,
      // The filtered view is made once per index and filter.
      pickIndex: identical(nextIndex, this.index) && nextTags == this.tags
          ? pickIndex
          : null,
      isReadingClips: isReadingClips ?? this.isReadingClips,
      preset: preset ?? this.preset,
      presetChosen: presetChosen ?? this.presetChosen,
      source: source ?? this.source,
      monthChoice: monthChoice ?? this.monthChoice,
      // `??` can't clear a field: the dates sheet asks for it.
      dateChoice: clearDateChoice ? null : dateChoice ?? this.dateChoice,
      picks: picks ?? this.picks,
      unavailable: unavailable ?? this.unavailable,
      includePrivate: includePrivate ?? this.includePrivate,
      // `??` can't clear a field: None clears it.
      transition: clearTransition ? null : transition ?? this.transition,
      upgradeOlderClips: upgradeOlderClips ?? this.upgradeOlderClips,
      olderClips: olderClips ?? this.olderClips,
      unreadClips: unreadClips ?? this.unreadClips,
      foreignClips: foreignClips ?? this.foreignClips,
      foreignDurationMs: foreignDurationMs ?? this.foreignDurationMs,
      // `??` can't clear a field: a draft nobody has read has no length.
      draftDurationMs: clearDraftDuration
          ? null
          : draftDurationMs ?? this.draftDurationMs,
      // `??` can't clear a field: removing the last track clears it.
      music: clearMusic ? null : music ?? this.music,
      musicNames: clearMusic
          ? const <String, String>{}
          : musicNames ?? this.musicNames,
      draft: draft ?? this.draft,
      launch: launch ?? this.launch,
      // A new launch brings its own shortfall and request (or none).
      spaceShortfall: launch == null ? this.spaceShortfall : spaceShortfall,
      request: launch == null ? this.request : request,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    profile,
    today,
    status,
    index,
    tags,
    isReadingClips,
    preset,
    presetChosen,
    source,
    monthChoice,
    dateChoice,
    picks,
    unavailable,
    includePrivate,
    transition,
    upgradeOlderClips,
    olderClips,
    unreadClips,
    foreignClips,
    foreignDurationMs,
    draftDurationMs,
    music,
    musicNames,
    draft,
    launch,
    spaceShortfall,
    request,
  ];
}
