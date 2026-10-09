import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/movie_render_event.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';

/// Progress of a movie made by the `MovieBuilder`: one [MovieBuildStarted],
/// [MovieBuildProgress] events, one [MovieBuildFinishing], then one
/// [MovieBuilt] (or an error).
sealed class MovieBuildEvent extends Equatable {
  const MovieBuildEvent();
}

/// The first event: the clips the movie joins, in play order. The progress
/// events index into this list.
final class MovieBuildStarted extends MovieBuildEvent {
  const MovieBuildStarted(this.clips);

  final List<ClipRef> clips;

  @override
  List<Object?> get props => <Object?>[clips];
}

/// The media engine's progress: a [MoviePreparing] or a
/// [MovieConcatenating] (never its `MovieCompleted`).
final class MovieBuildProgress extends MovieBuildEvent {
  const MovieBuildProgress(this.progress);

  final MovieRenderEvent progress;

  @override
  List<Object?> get props => <Object?>[progress];
}

/// The clips are joined: the movie is being saved into the gallery (a copy
/// on Android) and registered.
final class MovieBuildFinishing extends MovieBuildEvent {
  const MovieBuildFinishing();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The movie is in `Movies/` and registered: the last event.
final class MovieBuilt extends MovieBuildEvent {
  const MovieBuilt(
    this.movie, {
    this.skipped = const <ClipRef>[],
    this.leftOutPrivate = const <ClipRef>[],
  });

  final MovieEntry movie;

  /// The [MovieBuildStarted] clips left out because they cannot be read;
  /// [movie] counts only the clips joined.
  final List<ClipRef> skipped;

  /// The [MovieBuildStarted] clips left out because their file says they are
  /// private, which the library did not know when the movie was counted (a clip
  /// not read yet, right after a reinstall); the movie leaves private clips out
  /// unless the user included them.
  final List<ClipRef> leftOutPrivate;

  @override
  List<Object?> get props => <Object?>[movie, skipped, leftOutPrivate];
}
