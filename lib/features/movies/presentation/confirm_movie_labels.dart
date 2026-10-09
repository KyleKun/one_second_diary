import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show toBeginningOfSentenceCase;
import 'package:one_second_diary/core/l10n/display_text.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/movies/domain/movie_draft.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';

/// The confirmation's words for a movie, in the app language.
abstract final class ConfirmMovieLabels {
  /// Up to this many skipped days are listed; more are counted.
  static const int listedSkippedDays = 6;

  /// The movie's title, which also becomes its name in My movies (display
  /// text): "September 2026" (a month, this month), "2026" (this year, last
  /// year), "Sep 22 – Sep 28, 2026" (the last 7 or 30 days), "Mar 2024 – Sep
  /// 2026" (all time), "5 hand-picked clips".
  static String title(BuildContext context, MovieDraft draft) =>
      DisplayText.safe(
        toBeginningOfSentenceCase(switch (draft.source) {
          CustomMovieSource() => Strings.movieTitleHandPicked(
            draft.clips.length,
            format: MovieLabels.numberFormat(context),
          ),
          MonthMovieSource(:final int year, :final int month) =>
            MovieLabels.monthYear(context, year, month),
          PresetMovieSource(:final MoviePreset preset) => _presetTitle(
            context,
            preset,
            draft.range!,
          ),
          DateRangeMovieSource() => _daysTitle(context, draft.range!),
        }, Localizations.localeOf(context).toLanguageTag()),
      );

  /// The days without a clip, as the callout lists them: the day numbers within
  /// one month ("9, 21, 25"), else the short dates ("Aug 30, Sep 9").
  static String skippedDays(BuildContext context, MovieDraft draft) {
    final DayRange range = draft.range!;
    final bool oneMonth =
        range.first.year == range.last.year &&
        range.first.month == range.last.month;
    String label(LocalDay day) => oneMonth
        ? MovieLabels.numberFormat(context).format(day.day)
        : MovieLabels.shortDate(context, day);
    return <String>[
      for (final LocalDay day in draft.skippedDays) label(day),
    ].join(MovieLabels.listSeparator(context));
  }

  /// The tag filter line under the summary ("Tagged trip, kids · Without
  /// work"); null when the movie has no filter.
  static String? tagFilter(BuildContext context, MovieDraft draft) =>
      MovieLabels.tagFilter(
        context,
        tags: draft.tags.anyOf,
        without: draft.tags.noneOf,
      );

  static String _presetTitle(
    BuildContext context,
    MoviePreset preset,
    DayRange range,
  ) => switch (preset) {
    MoviePreset.thisMonth => MovieLabels.monthYear(
      context,
      range.first.year,
      range.first.month,
    ),
    MoviePreset.thisYear ||
    MoviePreset.lastYear => MovieLabels.year(context, range.first.year),
    MoviePreset.last7Days ||
    MoviePreset.last30Days => _daysTitle(context, range),
    MoviePreset.allTime =>
      range.first.year == range.last.year &&
              range.first.month == range.last.month
          ? MovieLabels.shortMonthYear(
              context,
              range.first.year,
              range.first.month,
            )
          : Strings.dateRangeValue(
              start: MovieLabels.shortMonthYear(
                context,
                range.first.year,
                range.first.month,
              ),
              end: MovieLabels.shortMonthYear(
                context,
                range.last.year,
                range.last.month,
              ),
            ),
  };

  /// A range of days: "Sep 22 – Sep 28, 2026", the year once unless the days
  /// span two ("Dec 28, 2025 – Jan 3, 2026"); one day is just that day.
  static String _daysTitle(BuildContext context, DayRange range) {
    if (range.first == range.last) {
      return MovieLabels.dateWithYear(context, range.first);
    }
    return Strings.dateRangeValue(
      start: range.first.year == range.last.year
          ? MovieLabels.shortDate(context, range.first)
          : MovieLabels.dateWithYear(context, range.first),
      end: MovieLabels.dateWithYear(context, range.last),
    );
  }
}
