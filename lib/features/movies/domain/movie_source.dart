import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';

/// Which clips a movie is made of.
sealed class MovieSource extends Equatable {
  const MovieSource();

  /// A quick range relative to today.
  const factory MovieSource.preset(MoviePreset preset, {TagFilter? tags}) =
      PresetMovieSource;

  /// One calendar month (also the Diary's "Make movie" shortcut).
  const factory MovieSource.month({
    required int year,
    required int month,
    TagFilter? tags,
  }) = MonthMovieSource;

  /// The days [range] covers, first through last ("Choose dates").
  const factory MovieSource.dateRange(DayRange range, {TagFilter? tags}) =
      DateRangeMovieSource;

  /// Clips picked one by one.
  const factory MovieSource.custom(Set<ClipRef> clips) = CustomMovieSource;
}

/// A source that is a range of days, with the tag filter the range's clips
/// pass through ([tags]; every clip without one).
sealed class RangedMovieSource extends MovieSource {
  const RangedMovieSource({this._tags});

  // Nullable so the constructors stay const (`TagFilter.none` is not).
  final TagFilter? _tags;

  /// The clips the range keeps: those [TagFilter.matches]; every clip when
  /// empty.
  TagFilter get tags => _tags ?? TagFilter.none;

  /// Whether a tag filter narrows this range.
  bool get hasTagFilter => tags.isNotEmpty;

  /// This range with [tags] as its filter.
  RangedMovieSource withTags(TagFilter tags);
}

final class PresetMovieSource extends RangedMovieSource {
  const PresetMovieSource(this.preset, {super.tags});

  final MoviePreset preset;

  @override
  PresetMovieSource withTags(TagFilter tags) =>
      PresetMovieSource(preset, tags: tags);

  @override
  List<Object?> get props => <Object?>[preset, tags];
}

final class MonthMovieSource extends RangedMovieSource {
  const MonthMovieSource({required this.year, required this.month, super.tags})
    : assert(month >= 1 && month <= 12, 'month must be 1-12');

  final int year;

  /// 1–12.
  final int month;

  @override
  MonthMovieSource withTags(TagFilter tags) =>
      MonthMovieSource(year: year, month: month, tags: tags);

  @override
  List<Object?> get props => <Object?>[year, month, tags];
}

final class DateRangeMovieSource extends RangedMovieSource {
  const DateRangeMovieSource(this.range, {super.tags});

  /// The days picked, first through last; resolved clamped to today, like a
  /// month, so a range ending in the future never reports future days as
  /// skipped.
  final DayRange range;

  @override
  DateRangeMovieSource withTags(TagFilter tags) =>
      DateRangeMovieSource(range, tags: tags);

  @override
  List<Object?> get props => <Object?>[range, tags];
}

final class CustomMovieSource extends MovieSource {
  const CustomMovieSource(this.clips);

  /// The picked clips; the movie orders them by day and ordinal, never by
  /// tap order.
  final Set<ClipRef> clips;

  @override
  List<Object?> get props => <Object?>[clips];
}
