import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';

/// Resolves a [MovieSource] against one profile's [ClipIndex]: the clips a
/// movie is made of, in play order (by day, then ordinal), each with its real
/// relPath, so clips in sub-folders resolve.
extension MovieSelection on ClipIndex {
  /// The clips of [source] on [today].
  List<ClipRef> clipsFor(
    MovieSource source, {
    required LocalDay today,
    bool includePrivate = false,
  }) => switch ((source, rangeOf(source, today: today))) {
    (CustomMovieSource(:final Set<ClipRef> clips), _) => _stillIndexed(clips),
    (final RangedMovieSource ranged, final DayRange range?) => _rangeIndex(
      ranged,
      includePrivate: includePrivate,
    ).clipsIn(range),
    (_, null) => const <ClipRef>[],
  };

  /// How many clips [clipsFor] would return; O(log n) for a range once its
  /// filtered view exists, so Create movie's clip count is live.
  int countClipsFor(
    MovieSource source, {
    required LocalDay today,
    bool includePrivate = false,
  }) => switch ((source, rangeOf(source, today: today))) {
    (CustomMovieSource(:final Set<ClipRef> clips), _) => _stillIndexed(
      clips,
    ).length,
    (final RangedMovieSource ranged, final DayRange range?) => _rangeIndex(
      ranged,
      includePrivate: includePrivate,
    ).countClipsIn(range),
    (_, null) => 0,
  };

  /// This index as [source] sees it: through its tag filter (this very index
  /// without one), then without the private clips unless [includePrivate].
  ClipIndex _rangeIndex(
    RangedMovieSource source, {
    required bool includePrivate,
  }) {
    final ClipIndex kept = filtered(source.tags);
    return includePrivate ? kept : kept.shareable;
  }

  /// The days [source] covers on [today]; null for picked clips, which are
  /// no range. "All time" starts at the first recorded day.
  DayRange? rangeOf(MovieSource source, {required LocalDay today}) =>
      switch (source) {
        PresetMovieSource(:final MoviePreset preset) => MovieRanges.preset(
          preset,
          today: today,
          firstRecorded: firstDay ?? today,
        ),
        MonthMovieSource(:final int year, :final int month) =>
          MovieRanges.month(year, month, today: today),
        DateRangeMovieSource(:final DayRange range) => MovieRanges.dateRange(
          range,
          today: today,
        ),
        CustomMovieSource() => null,
      };

  /// [picked] clips that are still visible, by day, then ordinal (the tap
  /// order never matters).
  List<ClipRef> _stillIndexed(Set<ClipRef> picked) =>
      <ClipRef>[
        for (final ClipRef clip in picked)
          if (clipsOn(clip.day).contains(clip)) clip,
      ]..sort((ClipRef a, ClipRef b) {
        final int byDay = a.day.compareTo(b.day);
        return byDay != 0 ? byDay : a.ordinal.compareTo(b.ordinal);
      });
}

/// The day ranges of Create movie (presets, months and picked dates).
abstract final class MovieRanges {
  /// The days [preset] covers on [today]. "Last N days" is today and the N-1
  /// days before it; "this month/year" runs from its first day through today;
  /// "last year" is the whole previous calendar year; "all time" runs from
  /// [firstRecorded] through today.
  static DayRange preset(
    MoviePreset preset, {
    required LocalDay today,
    required LocalDay firstRecorded,
  }) => switch (preset) {
    MoviePreset.allTime => DayRange(first: firstRecorded, last: today),
    MoviePreset.last7Days => DayRange(first: today.addDays(-6), last: today),
    MoviePreset.last30Days => DayRange(first: today.addDays(-29), last: today),
    MoviePreset.thisMonth => DayRange(
      first: LocalDay(today.year, today.month, 1),
      last: today,
    ),
    MoviePreset.thisYear => DayRange(
      first: LocalDay(today.year, 1, 1),
      last: today,
    ),
    MoviePreset.lastYear => DayRange(
      first: LocalDay(today.year - 1, 1, 1),
      last: LocalDay(today.year - 1, 12, 31),
    ),
  };

  /// The whole calendar month [year]-[month], clamped to [today] so the current
  /// month never reports future days as skipped.
  static DayRange month(int year, int month, {required LocalDay today}) {
    final LocalDay first = LocalDay(year, month, 1);
    final LocalDay last =
        (month == 12 ? LocalDay(year + 1, 1, 1) : LocalDay(year, month + 1, 1))
            .addDays(-1);
    return DayRange(first: first, last: last.isAfter(today) ? today : last);
  }

  /// [range] as picked, clamped to [today] (a wrong clock, or a day that was
  /// today when picked): the days are compared as calendar days, so the count
  /// is the same across a DST change.
  static DayRange dateRange(DayRange range, {required LocalDay today}) =>
      range.last.isAfter(today)
      ? DayRange(first: range.first, last: today)
      : range;
}
