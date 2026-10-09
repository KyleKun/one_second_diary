import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/journey_stats.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/journey/domain/places_snapshot.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';

/// Whether the Journey tab has its statistics.
enum JourneyStatus {
  /// The active profile's diary has not been read yet.
  loading,

  /// [JourneyState.stats] describe the active profile.
  ready,

  /// The active profile's diary could not be read (the scan failed before
  /// any snapshot).
  failed,
}

/// The Journey tab: the active profile's statistics, tags and places, and
/// the movies made.
final class JourneyState extends Equatable {
  const JourneyState({
    required this.status,
    this.stats,
    this.clipCount = 0,
    this.tagCounts = const <TagCount>[],
    this.places,
    this.movies,
  });

  const JourneyState.loading() : this(status: JourneyStatus.loading);

  final JourneyStatus status;

  /// The stats; null while [JourneyStatus.loading] or failed.
  final JourneyStats? stats;

  /// The active profile's visible clips ("312 clips available"; a movie
  /// needs at least two).
  final int clipCount;

  /// The profile's tags, most used first (`ClipIndex.tagCounts`).
  final List<TagCount> tagCounts;

  /// Where the clips were filmed; null while loading or failed.
  final PlacesSnapshot? places;

  /// Every movie in `Movies/`, newest first, whatever its profile; null
  /// until the folder has been read.
  final List<MovieEntry>? movies;

  int? get moviesMade => movies?.length;

  JourneyState copyWith({List<MovieEntry>? movies}) => JourneyState(
    status: status,
    stats: stats,
    clipCount: clipCount,
    tagCounts: tagCounts,
    places: places,
    movies: movies ?? this.movies,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    stats,
    clipCount,
    tagCounts,
    places,
    movies,
  ];
}
