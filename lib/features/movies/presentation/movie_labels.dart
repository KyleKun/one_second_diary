import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/presentation/imports/import_labels.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/domain/movie_file_name.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';

/// The movie screens' words and formats in the app language, through the
/// app's formatters (`LocaleFormats`: none is built in a `build`).
abstract final class MovieLabels {
  /// The radio's label of [preset].
  static String preset(MoviePreset preset) => switch (preset) {
    MoviePreset.allTime => Strings.allTime,
    MoviePreset.last7Days => Strings.last7Days,
    MoviePreset.last30Days => Strings.last30Days,
    MoviePreset.thisMonth => Strings.thisMonth,
    MoviePreset.thisYear => Strings.thisYear,
    MoviePreset.lastYear => Strings.lastYear,
  };

  /// The title [movie] shows: its base title, led by the CURRENT name of a
  /// profile other than Default ("Children · 2025"; a deleted profile's key
  /// stands in).
  static String movieTitle(BuildContext context, MovieEntry movie) => _titled(
    context,
    movie,
    context.select<ProfilesCubit, String?>(
      (ProfilesCubit profiles) => _nameOf(profiles, movie.profile),
    ),
  );

  /// [movieTitle] as it is now, outside a `build` (a dialog's text).
  static String movieTitleNow(BuildContext context, MovieEntry movie) =>
      _titled(
        context,
        movie,
        _nameOf(context.read<ProfilesCubit>(), movie.profile),
      );

  /// [movie]'s base title (no profile's name) as screens show it and the rename
  /// dialog edits it.
  static String baseTitle(BuildContext context, MovieEntry movie) {
    final LocalDay? day = MovieFileName.dayOf(
      PathNames.fileNameOf(movie.fileName),
    );
    return day != null && movie.title == day.fileStem
        ? dateWithYear(context, day)
        : movie.title;
  }

  static String? _nameOf(ProfilesCubit profiles, ProfileKey? owner) =>
      owner == null || owner.isDefault
      ? null
      : profiles.state.profiles
            .where((Profile profile) => profile.key == owner)
            .firstOrNull
            ?.displayName;

  static String _titled(BuildContext context, MovieEntry movie, String? name) {
    final String title = baseTitle(context, movie);
    final ProfileKey? owner = movie.profile;
    if (owner == null || owner.isDefault) return title;
    return Strings.movieNameWithProfile(
      profile: name ?? owner.value,
      name: title,
    );
  }

  /// How the app language separates the items of a list ("a, b"; "a、b").
  static String listSeparator(BuildContext context) =>
      switch (Localizations.localeOf(context).languageCode) {
        'zh' || 'ja' => '、',
        _ => ', ',
      };

  /// [tags] as one list ("trip, kids").
  static String tagList(BuildContext context, Iterable<String> tags) =>
      tags.join(listSeparator(context));

  /// What a tag filter says about a movie: "Tagged trip, kids",
  /// "Without work", both joined with a middle dot; null without a filter.
  static String? tagFilter(
    BuildContext context, {
    required Iterable<String> tags,
    required Iterable<String> without,
  }) {
    final List<String> parts = <String>[
      if (tags.isNotEmpty) Strings.movieTagged(tags: tagList(context, tags)),
      if (without.isNotEmpty)
        Strings.movieWithout(tags: tagList(context, without)),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// "25 clips", counted as the locale writes numbers.
  static String clips(BuildContext context, int count) =>
      Strings.clipCount(count, format: numberFormat(context));

  /// What My movies and the player say under [movie]'s title: its clips and,
  /// once known, how long it runs ("25 clips · 1:23", as [clock]); null for a
  /// movie whose clips are unknown (made by an older install).
  static String? clipsLine(BuildContext context, MovieEntry movie) {
    final int? count = movie.clipCount;
    if (count == null) return null;
    final int? durationMs = movie.durationMs;
    return <String>[
      clips(context, count),
      if (durationMs != null) clock(Duration(milliseconds: durationMs)),
    ].join(' · ');
  }

  /// [time] in round words: "45 s", "12 min", "2 h 14 min"
  /// (`ImportLabels.roughDuration`).
  static String roughDuration(Duration time) =>
      ImportLabels.roughDuration(time);

  /// [time] as a player's clock: "0:07", "12:30", "1:02:03".
  static String clock(Duration time) {
    final int seconds = time.inSeconds < 0 ? 0 : time.inSeconds;
    final int hours = seconds ~/ 3600;
    final int minutes = seconds ~/ 60 % 60;
    final String secs = (seconds % 60).toString().padLeft(2, '0');
    return hours == 0
        ? '$minutes:$secs'
        : '$hours:${minutes.toString().padLeft(2, '0')}:$secs';
  }

  /// Counts as the locale writes them ("1,234").
  static NumberFormat numberFormat(BuildContext context) =>
      LocaleFormats.of(context).numbers;

  /// "Jan" (the standalone form, for languages that inflect months).
  static String shortMonth(BuildContext context, int month) =>
      _date(context, 'LLL').format(DateTime(2000, month));

  /// "January" (standalone), for screen readers.
  static String month(BuildContext context, int month) =>
      _date(context, 'LLLL').format(DateTime(2000, month));

  /// "2026" as the locale writes years.
  static String year(BuildContext context, int year) =>
      _date(context, 'y').format(DateTime(year));

  /// "Sep 1" (`MMMd`): a picker tile's day.
  static String shortDate(BuildContext context, LocalDay day) =>
      _date(context, 'MMMd').format(day.toLocalDateTime());

  /// "September 1, 2026" (`yMMMMd`), for screen readers.
  static String fullDate(BuildContext context, LocalDay day) =>
      _date(context, 'yMMMMd').format(day.toLocalDateTime());

  /// "September 2026" (`yMMMM`): a picker month, a month's movie.
  static String monthYear(BuildContext context, int year, int month) =>
      _date(context, 'yMMMM').format(DateTime(year, month));

  /// "Mar 2024" (`yMMM`): the ends of an "All time" movie.
  static String shortMonthYear(BuildContext context, int year, int month) =>
      _date(context, 'yMMM').format(DateTime(year, month));

  /// "Sep 28, 2026" (`yMMMd`): the end of a range of days.
  static String dateWithYear(BuildContext context, LocalDay day) =>
      _date(context, 'yMMMd').format(day.toLocalDateTime());

  /// [bytes] as the phone's settings show sizes, rounded up so what it says to
  /// free is enough: "850 MB", "1.3 GB" (1 000-based, one decimal from a
  /// gigabyte on).
  static String size(BuildContext context, int bytes) {
    const int megabyte = 1000 * 1000;
    const int gigabyte = 1000 * megabyte;
    if (bytes < gigabyte) {
      final int megabytes = (bytes / megabyte).ceil();
      return Strings.movieSizeMegabytes(
        size: numberFormat(context).format(megabytes < 1 ? 1 : megabytes),
      );
    }
    final double gigabytes = (bytes / gigabyte * 10).ceil() / 10;
    return Strings.movieSizeGigabytes(
      size: LocaleFormats.of(context).pattern('#,##0.#').format(gigabytes),
    );
  }

  /// [fraction] (0–1) as the locale writes a whole percent, rounded down so
  /// it never says more than is done: "45%", "45 %" (fr), "%45" (tr).
  static String percent(BuildContext context, double fraction) =>
      LocaleFormats.of(context).percent
      // The epsilon keeps .29 at 29 % (.29 × 100 is 28.999…).
      .format((fraction.clamp(0, 1) * 100 + 1e-9).floor() / 100);

  /// The app language's format of the intl [skeleton].
  static DateFormat _date(BuildContext context, String skeleton) =>
      LocaleFormats.of(context).date(skeleton);
}
