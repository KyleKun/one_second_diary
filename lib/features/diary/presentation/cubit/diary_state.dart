import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/diary/domain/clip_filter.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_day.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';

/// "[recorded] of [total] days".
typedef MonthCount = ({int recorded, int total});

/// The clips a player keeps warm around the one it shows.
typedef PlayerNeighbours = ({ClipRef? previous, ClipRef? next});

/// What the Diary tab shows (the title row's toggle).
enum DiaryView {
  /// The month grid and the selected day.
  calendar,

  /// Every recorded day, newest first.
  memories,
}

/// Where deleting a clip is.
enum ClipDeletion {
  /// Nothing asked.
  idle,

  /// The clip is being deleted; the dialog waits.
  deleting,

  /// [DiaryState.deletedClip] is gone ("Video deleted").
  deleted,

  /// The phone refused; the clip stays ("Couldn't delete this video").
  failed,
}

/// Where the viewer was opened from in the calendar: that surface is the
/// end of the clip's flight, there and back. The selected day's cell and
/// the mini player show the same clip, and two heroes with one tag can't
/// both fly.
enum ViewerOrigin {
  /// The mini player's expand (and Memories' cards).
  player,

  /// A long press on a recorded day of the grid.
  cell,
}

/// Whether the active profile's diary has been read.
enum DiaryStatus {
  /// Its folder is still being listed (the launch reads it after the
  /// first frame); the grid shows every past day as loading.
  loading,

  /// [DiaryState.index] holds its clips.
  ready,

  /// Its folder could not be read (logged by the `ClipRepository`); the
  /// days stay unknown until a rescan reads it.
  failed,
}

/// The Diary tab: the active profile's clips, the month shown and the day
/// selected.
final class DiaryState extends Equatable {
  const DiaryState({
    required this.profile,
    required this.today,
    required this.month,
    this.index,
    this.filter = const ClipFilter.none(),
    this._filteredIndex,
    this.selected,
    this.shown,
    this.unreadable = false,
    this.alternativeColors = false,
    this.view = DiaryView.calendar,
    this.muted = true,
    this.autoPlay = true,
    this.adding = false,
    this.deletion = ClipDeletion.idle,
    this.deletedClip,
    this.viewerOrigin = ViewerOrigin.player,
    this.viewerOpen = false,
    this.revealed,
  });

  /// The fewest clips a movie takes (`movieInsufficientVideos`).
  static const int minMovieClips = 2;

  /// The oldest month the calendar reaches, so old footage can still be
  /// imported: January 2018, or the month of an older clip.
  static const DiaryMonth historyStart = DiaryMonth(2018, 1);

  /// The active profile, whose diary this is.
  final Profile profile;

  /// Its clips; null until its folder has been read.
  final ClipIndex? index;

  /// The Diary's filter (tags, "Without tags", a text search); empty
  /// unless the user set one this session.
  final ClipFilter filter;

  final ClipIndex? _filteredIndex;

  /// The clips [filter] keeps: [index] itself while the filter is empty,
  /// else the sub-index the cubit made of it when the filter or the
  /// snapshot last changed (identity-stable in between, so what is built
  /// on it is kept). The selected day, the player, Memories and the viewer
  /// read this one; null until the diary has been read.
  ClipIndex? get filteredIndex =>
      filter.isEmpty ? index : _filteredIndex ?? index;

  /// Whether a filter is on.
  bool get isFiltered => filter.isNotEmpty;

  /// The clips [filter] keeps ("12 videos match"); 0 until read.
  int get matchCount => filteredIndex?.clipCount ?? 0;

  /// Today, which moves on at midnight.
  final LocalDay today;

  /// The month the calendar shows.
  final DiaryMonth month;

  /// The day the player (or the missed-day panel) shows; null when the
  /// month shown has nothing to select.
  final LocalDay? selected;

  /// The clip of [selected] the user paged to; null shows its first.
  final ClipRef? shown;

  /// The first read of the diary failed.
  final bool unreadable;

  /// "Alternative calendar colors": recorded days get a blue check and
  /// missed days a yellow outline.
  final bool alternativeColors;

  /// The calendar or Memories; kept while the tab lives.
  final DiaryView view;

  /// The player plays without sound (it starts muted, mixing with the
  /// user's music, until the user turns the sound on).
  final bool muted;

  /// The player plays the selected clip on its own (`calendarAutoPlay`:
  /// the user's last play or pause, on by default).
  final bool autoPlay;

  /// A clip is being added to the selected day (the picker, then the clip
  /// editor); its buttons wait.
  final bool adding;

  /// The last delete asked, and its clip.
  final ClipDeletion deletion;
  final ClipRef? deletedClip;

  /// Where the viewer was last opened from: the clip's flight ends there.
  final ViewerOrigin viewerOrigin;

  /// The viewer is open over the Diary, which holds still under it (it
  /// shows through while the viewer is dragged away).
  final bool viewerOpen;

  DiaryStatus get status => switch ((index, unreadable)) {
    (ClipIndex(), _) => DiaryStatus.ready,
    (null, true) => DiaryStatus.failed,
    (null, false) => DiaryStatus.loading,
  };

  /// The month of [today]: the last one the calendar shows (no future
  /// months).
  DiaryMonth get thisMonth => DiaryMonth.of(today);

  /// The first month the calendar shows.
  DiaryMonth get earliestMonth {
    final LocalDay? firstClip = index?.firstDay;
    if (firstClip == null) return historyStart;
    final DiaryMonth first = DiaryMonth.of(firstClip);
    return first.isBefore(historyStart) ? first : historyStart;
  }

  bool get canShowPrevious => month.isAfter(earliestMonth);

  bool get canShowNext => month.isBefore(thisMonth);

  /// The day [month] opens on: today when it has a clip, else the month's
  /// latest recorded day, else today in this month and nothing in a past
  /// month without clips. Under a filter, the clips are the ones it keeps,
  /// and today is skipped when the filter leaves its clips out.
  LocalDay? defaultDayOf(DiaryMonth month) {
    final ClipIndex? index = filteredIndex;
    final bool isThisMonth = month.contains(today);
    if (index == null || (isThisMonth && index.hasDay(today))) {
      return isThisMonth ? today : null;
    }
    final LocalDay? latest = index.previousRecordedDay(month.last.addDays(1));
    if (latest != null && month.contains(latest)) return latest;
    return isThisMonth && dayOf(today).isSelectable ? today : null;
  }

  /// Every clip of the selected day the filter keeps, in recording order
  /// (the player steps through them); none for a day without clips.
  List<ClipRef> get selectedClips => switch ((filteredIndex, selected)) {
    (final ClipIndex index, final LocalDay day) => index.clipsOn(day),
    _ => const <ClipRef>[],
  };

  /// The clip the player shows: the one the user paged to, while the
  /// selected day still has it, else the day's first; null without one.
  ClipRef? get shownClip {
    final List<ClipRef> clips = selectedClips;
    if (clips.isEmpty) return null;
    return clips.contains(shown) ? shown : clips.first;
  }

  /// The private clip the user uncovered in the player (its tap); null for
  /// none.
  final ClipRef? revealed;

  /// Whether [clip]'s picture and caption are hidden in the player: a
  /// private clip not uncovered yet.
  bool isCovered(ClipRef clip) =>
      (index?.isPrivate(clip) ?? false) && revealed != clip;

  /// The player's private [clip] was uncovered.
  DiaryState withRevealed(ClipRef clip) => _copy(revealed: clip);

  /// No private clip is uncovered.
  DiaryState get withoutRevealed => _copy(revealed: null);

  /// Where [shownClip] is among [selectedClips] (0 without one).
  int get shownPosition {
    final ClipRef? clip = shownClip;
    return clip == null ? 0 : selectedClips.indexOf(clip);
  }

  /// The clips played just before and after [clip], kept warm by the
  /// player (the day's own clips first, then the closest recorded days,
  /// among the clips the filter keeps). A record, so a widget selecting it
  /// rebuilds only when they change.
  PlayerNeighbours neighboursOf(ClipRef clip) => switch (filteredIndex) {
    final ClipIndex index => (
      previous: index.previousClip(clip),
      next: index.nextClip(clip),
    ),
    null => (previous: null, next: null),
  };

  /// Every clip of [day] the filter keeps, in recording order; none before
  /// the diary is read. O(1).
  List<ClipRef> clipsOf(LocalDay day) =>
      filteredIndex?.clipsOn(day) ?? const <ClipRef>[];

  /// Whether "Make movie" can make one of [month] (the month shown, or a
  /// Memories header): its clips, not days, as two clips of one day make a
  /// movie. O(log n).
  bool canMakeMovieOf(DiaryMonth month) =>
      (index?.countClipsIn(month.range) ?? 0) >= minMovieClips;

  /// [canMakeMovieOf] for the movie the "Make movie" chip starts: of the
  /// clips the filter's tags keep when a tag filter is on (the chip hands
  /// those tags to the movie flow), else of every clip of [month].
  bool canMakeFilteredMovieOf(DiaryMonth month) => filter.tags.isEmpty
      ? canMakeMovieOf(month)
      : (index?.filtered(filter.tags).countClipsIn(month.range) ?? 0) >=
            minMovieClips;

  /// "25 of 28 days" for [month]: the days with a clip, out of the days
  /// that count, from the profile's first clip (days before it are
  /// neither missed nor counted) through today. Null until the diary has
  /// been read. O(log n).
  MonthCount? get monthCount => monthCountOf(month);

  /// [monthCount] of any [month] (a Memories header).
  MonthCount? monthCountOf(DiaryMonth month) {
    final ClipIndex? index = this.index;
    if (index == null) return null;
    final LocalDay? firstClip = index.firstDay;
    if (firstClip == null) return (recorded: 0, total: 0);
    final int from = math.max(month.first.epochDay, firstClip.epochDay);
    final int until = math.min(month.last.epochDay, today.epochDay);
    return (
      recorded: index
          .monthSummary(year: month.year, month: month.month, today: today)
          .recorded,
      total: until < from ? 0 : until - from + 1,
    );
  }

  /// What the calendar shows for [day], in O(1): one hash lookup in the
  /// index (two under a filter). A recorded day none of whose clips the
  /// filter keeps is [DiaryDayKind.filteredOut].
  DiaryDay dayOf(LocalDay day) {
    final bool isToday = day == today;
    final bool isSelected = day == selected;
    final ClipIndex? index = this.index;
    if (day.isAfter(today)) {
      return DiaryDay(
        day: day,
        kind: DiaryDayKind.future,
        isSelected: isSelected,
      );
    }
    if (index == null) {
      return DiaryDay(
        day: day,
        kind: DiaryDayKind.unknown,
        isToday: isToday,
        isSelected: isSelected,
      );
    }
    final List<ClipRef> clips = index.clipsOn(day);
    if (clips.isNotEmpty) {
      final ClipIndex filtered = filteredIndex ?? index;
      final List<ClipRef> kept = identical(filtered, index)
          ? clips
          : filtered.clipsOn(day);
      final List<ClipRef> shown = kept.isEmpty ? clips : kept;
      return DiaryDay(
        day: day,
        kind: kept.isEmpty ? DiaryDayKind.filteredOut : DiaryDayKind.recorded,
        clip: shown.first,
        stamp: index.stampOf(shown.first),
        clipCount: shown.length,
        isToday: isToday,
        isSelected: isSelected,
      );
    }
    final LocalDay? firstClip = index.firstDay;
    return DiaryDay(
      day: day,
      kind: firstClip == null || day.isBefore(firstClip)
          ? DiaryDayKind.beforeFirstClip
          : DiaryDayKind.missed,
      isToday: isToday,
      isSelected: isSelected,
    );
  }

  /// This state showing [month] with [selected] (nothing when null), on
  /// the day's first clip.
  DiaryState showing(
    DiaryMonth month, {
    required LocalDay? selected,
    ClipRef? clip,
  }) => _copy(month: month, selected: selected, shown: clip);

  /// This state showing the clip at [position] of the selected day; the
  /// same state when the day has no such clip.
  DiaryState showingClipAt(int position) {
    final List<ClipRef> clips = selectedClips;
    if (position < 0 || position >= clips.length) return this;
    return _copy(shown: clips[position]);
  }

  /// This state showing [month] on its default day.
  DiaryState opening(DiaryMonth month) =>
      showing(month, selected: defaultDayOf(month));

  /// This state over [index], a newer snapshot of the same profile, with
  /// [filtered] the clips of it the filter keeps (the cubit's pass; not
  /// needed while the filter is empty).
  DiaryState withIndex(ClipIndex index, {ClipIndex? filtered}) {
    assert(filter.isEmpty || filtered != null, 'the filtered snapshot');
    return _copy(index: index, filteredIndex: filtered, unreadable: false);
  }

  /// This state under [filter], keeping [filtered] of [index] (null before
  /// the diary is read).
  DiaryState withFilter(ClipFilter filter, {required ClipIndex? filtered}) =>
      _copy(filter: filter, filteredIndex: filtered);

  /// This state after the diary could not be read.
  DiaryState get asUnreadable => _copy(unreadable: true);

  /// This state reading the diary again ("Try again").
  DiaryState get readingAgain => _copy(unreadable: false);

  DiaryState withToday(LocalDay today) => _copy(today: today);

  DiaryState withAlternativeColors({required bool on}) =>
      _copy(alternativeColors: on);

  DiaryState withView(DiaryView view) => _copy(view: view);

  DiaryState withSound({required bool on}) => _copy(muted: !on);

  DiaryState withDeletion(ClipDeletion deletion, {required ClipRef clip}) =>
      _copy(deletion: deletion, deletedClip: clip);

  DiaryState withAdding({required bool adding}) => _copy(adding: adding);

  DiaryState withAutoPlay({required bool on}) => _copy(autoPlay: on);

  DiaryState withViewerOpenFrom(ViewerOrigin origin) =>
      _copy(viewerOrigin: origin, viewerOpen: true);

  /// This state once the viewer closed (its flight ends where it opened).
  DiaryState get withViewerClosed => _copy(viewerOpen: false);

  DiaryState _copy({
    ClipIndex? index,
    ClipFilter? filter,
    Object? filteredIndex = _keep,
    LocalDay? today,
    DiaryMonth? month,
    Object? selected = _keep,
    Object? shown = _keep,
    bool? unreadable,
    bool? alternativeColors,
    DiaryView? view,
    bool? muted,
    bool? autoPlay,
    bool? adding,
    ClipDeletion? deletion,
    ClipRef? deletedClip,
    ViewerOrigin? viewerOrigin,
    bool? viewerOpen,
    Object? revealed = _keep,
  }) => DiaryState(
    profile: profile,
    index: index ?? this.index,
    filter: filter ?? this.filter,
    filteredIndex: identical(filteredIndex, _keep)
        ? _filteredIndex
        : filteredIndex as ClipIndex?,
    today: today ?? this.today,
    month: month ?? this.month,
    selected: identical(selected, _keep)
        ? this.selected
        : selected as LocalDay?,
    shown: identical(shown, _keep) ? this.shown : shown as ClipRef?,
    unreadable: unreadable ?? this.unreadable,
    alternativeColors: alternativeColors ?? this.alternativeColors,
    view: view ?? this.view,
    muted: muted ?? this.muted,
    autoPlay: autoPlay ?? this.autoPlay,
    adding: adding ?? this.adding,
    deletion: deletion ?? this.deletion,
    deletedClip: deletedClip ?? this.deletedClip,
    viewerOrigin: viewerOrigin ?? this.viewerOrigin,
    viewerOpen: viewerOpen ?? this.viewerOpen,
    revealed: identical(revealed, _keep) ? this.revealed : revealed as ClipRef?,
  );

  static const Object _keep = Object();

  @override
  List<Object?> get props => <Object?>[
    profile,
    index,
    filter,
    _filteredIndex,
    today,
    month,
    selected,
    shown,
    unreadable,
    alternativeColors,
    view,
    muted,
    autoPlay,
    adding,
    deletion,
    deletedClip,
    viewerOrigin,
    viewerOpen,
    revealed,
  ];
}
