import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';

/// Progress of a movie build, emitted by `MediaEngine.renderMovie`.
///
/// The stream emits [MoviePreparing] events, then [MovieConcatenating]
/// events, then exactly one [MovieCompleted] and closes. A failure closes it
/// with a `VideoProcessingException` error, a cancellation with a
/// `CancelledException`, a movie left with fewer than two readable clips
/// with a `NotEnoughClipsException`; in every case no partial output is
/// left behind.
///
/// Every index is into the request's clips, whether or not some were left
/// out ([MovieCompleted.skipped]).
sealed class MovieRenderEvent extends Equatable {
  const MovieRenderEvent();
}

/// Clip [index] (0-based) of [total] is being checked or normalised.
final class MoviePreparing extends MovieRenderEvent {
  const MoviePreparing({required this.index, required this.total});

  final int index;
  final int total;

  @override
  List<Object?> get props => <Object?>[index, total];
}

/// The join is [fraction] done (0–1, by duration) and is currently copying
/// clip [currentIndex] (0-based).
final class MovieConcatenating extends MovieRenderEvent {
  const MovieConcatenating({
    required this.fraction,
    required this.currentIndex,
  });

  final double fraction;
  final int currentIndex;

  @override
  List<Object?> get props => <Object?>[fraction, currentIndex];
}

/// The movie is complete at [outputPath].
final class MovieCompleted extends MovieRenderEvent {
  const MovieCompleted({
    required this.outputPath,
    required this.durationMs,
    this.skipped = const <int>[],
    this.leftOutPrivate = const <int>[],
    this.chapters = const <MovieChapter>[],
    this.transitions = 0,
    this.hardCuts = 0,
  });

  final String outputPath;
  final int durationMs;

  /// The chapters written into the movie, one per clip that made it, in
  /// movie order, with the boundaries the engine measured; empty when the
  /// request asked for none.
  final List<MovieChapter> chapters;

  /// The clips left out because they cannot be read (ffprobe cannot open
  /// them, or they have no video stream), in order; empty for a movie of
  /// every clip asked for.
  final List<int> skipped;

  /// The clips left out because the probe found them private
  /// (`MovieRenderRequest.excludePrivate`), in order.
  final List<int> leftOutPrivate;

  /// The boundaries joined with the requested transition, and those left
  /// as hard cuts because a clip beside them could not be cut at a
  /// keyframe; both 0 for a movie made without transitions.
  final int transitions;
  final int hardCuts;

  @override
  List<Object?> get props => <Object?>[
    outputPath,
    durationMs,
    skipped,
    leftOutPrivate,
    chapters,
    transitions,
    hardCuts,
  ];
}
