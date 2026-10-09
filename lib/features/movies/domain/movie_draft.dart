import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/movies/domain/movie_rules.dart';
import 'package:one_second_diary/features/movies/domain/movie_selection.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';

/// The movie the confirmation screen shows: the clips [source] finds in one
/// profile's index, in play order, and what the screen says about them.
final class MovieDraft {
  const MovieDraft._({
    required this.source,
    required this.clips,
    required this.range,
    required this.skippedDays,
    required this.clipBytes,
    required this.mosaic,
    required this.includePrivate,
    required this.privateIncluded,
    required this.privateLeftOut,
    required this.tags,
    required this.tagsLeftOut,
  });

  /// The draft of [source] over [index] on [today].
  factory MovieDraft.of(
    ClipIndex index,
    MovieSource source, {
    required LocalDay today,
    bool includePrivate = false,
  }) {
    final TagFilter tags = switch (source) {
      RangedMovieSource(:final TagFilter tags) => tags,
      CustomMovieSource() => TagFilter.none,
    };
    // The range's clips through its tag filter (the index itself without one):
    // what the private counts are about.
    final ClipIndex filtered = index.filtered(tags);
    final DayRange? range = index.rangeOf(source, today: today);
    final List<ClipRef> clips = range == null
        ? index.clipsFor(source, today: today, includePrivate: includePrivate)
        : (includePrivate ? filtered : filtered.shareable).clipsIn(range);
    int bytes = 0;
    int privateIncluded = 0;
    for (final ClipRef clip in clips) {
      bytes += index.stampOf(clip)?.sizeBytes ?? 0;
      if (index.isPrivate(clip)) privateIncluded++;
    }
    return MovieDraft._(
      source: source,
      clips: List<ClipRef>.unmodifiable(clips),
      range: range,
      // Of every clip, private or tagged or not: a day whose clips are private,
      // or none of them match the filter, was recorded, not skipped.
      skippedDays: range == null
          ? const <LocalDay>[]
          : List<LocalDay>.unmodifiable(index.skippedDays(range, today: today)),
      clipBytes: bytes,
      mosaic: List<ClipRef>.unmodifiable(_mosaicOf(clips)),
      includePrivate: includePrivate,
      privateIncluded: privateIncluded,
      // What the filtered range holds beyond the movie's clips is private
      // (the full index would count the filtered-out clips as private).
      privateLeftOut: range == null
          ? 0
          : filtered.countClipsIn(range) - clips.length,
      tags: tags,
      // What the range holds, private clips aside, beyond the movie's
      // clips is what the tag filter left out.
      tagsLeftOut: range == null || tags.isEmpty
          ? 0
          : (includePrivate ? index : index.shareable).countClipsIn(range) -
                clips.length,
    );
  }

  /// The mosaic's cells: 4 × 4.
  static const int mosaicCells = 16;

  final MovieSource source;

  /// The clips the movie joins, by day, then ordinal.
  final List<ClipRef> clips;

  /// The days the source covers, through today; null for picked clips.
  final DayRange? range;

  /// The days of [range] without a clip.
  final List<LocalDay> skippedDays;

  /// The size of [clips] on disk, in bytes (the free-space check).
  final int clipBytes;

  /// Whether the range's private clips are in ([clips] picked by hand
  /// never depend on it).
  final bool includePrivate;

  /// The private clips among [clips].
  final int privateIncluded;

  /// The private clips of [range] that are not in the movie; 0 for clips
  /// picked by hand.
  final int privateLeftOut;

  /// The private clips the "Include private clips" switch is about: those of
  /// [range] the tag filter keeps, in the movie or not; 0 for clips picked by
  /// hand.
  int get privateInRange =>
      range == null ? 0 : privateIncluded + privateLeftOut;

  /// The tag filter the range's clips went through; empty for clips picked
  /// by hand and for a range without one.
  final TagFilter tags;

  /// The clips of [range] (private ones aside, unless included) the tag
  /// filter left out; 0 without a filter.
  final int tagsLeftOut;

  /// The clips of the 16 mosaic cells, in order: 16 sampled evenly from the
  /// first clip to the last, or, with fewer, the clips repeated in order; none
  /// without clips.
  final List<ClipRef> mosaic;

  /// Whether the movie has enough clips to be made.
  bool get canMake => clips.length >= MovieRules.minClips;

  static List<ClipRef> _mosaicOf(List<ClipRef> clips) {
    final int n = clips.length;
    if (n == 0) return const <ClipRef>[];
    // Evenly from the first clip to the last, or each clip in turn.
    int cellOf(int i) =>
        n >= mosaicCells ? (i * (n - 1) / (mosaicCells - 1)).round() : i % n;
    return <ClipRef>[for (int i = 0; i < mosaicCells; i++) clips[cellOf(i)]];
  }
}
