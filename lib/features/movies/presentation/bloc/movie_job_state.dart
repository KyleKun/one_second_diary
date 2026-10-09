import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_event.dart';

/// Where the movie job is.
enum MovieJobStatus {
  /// No movie is being made, or its end was dismissed.
  idle,

  /// Started: the clips are known, nothing is processed yet.
  preparing,

  /// Clips are being processed and joined ([MovieJobState.progress]).
  rendering,

  /// The clips are joined; the movie is being saved into the gallery. Every
  /// clip is done, the progress holds at [MovieJobState.finishingProgress].
  finishing,

  /// The user stopped it; the builder is stopping the engine and deleting
  /// what it made.
  cancelling,

  /// The movie is in `Movies/` ([MovieJobState.movie]).
  done,

  /// It could not be made ([MovieJobState.failure]); nothing was kept.
  failed,

  /// The user stopped it; nothing was kept.
  cancelled,
}

/// Why a movie could not be made.
enum MovieJobFailure {
  /// Fewer than two clips were left to join (deleted meanwhile, or the
  /// others cannot be read: [MovieJobState.skippedClips]).
  notEnoughClips,

  /// The phone filled up while the movie was made;
  /// [MovieJobState.spaceShortfall] says how much to free when known.
  noSpace,

  /// Anything else: ffmpeg, the gallery, the storage.
  failed,
}

/// The app-scoped movie job: the making page draws it and the created page
/// shows its movie.
final class MovieJobState extends Equatable {
  const MovieJobState({
    required this.status,
    this.request,
    this.clips = const <ClipRef>[],
    this.currentIndex,
    this.processed = 0,
    this.progress = 0,
    this.movie,
    this.failure,
    this.spaceShortfall,
    this.skippedClips = 0,
    this.leftOutPrivateClips = 0,
  });

  const MovieJobState.idle() : this(status: MovieJobStatus.idle);

  /// The most [progress] reads before the movie is saved: the percent
  /// holds at 99 until it is.
  static const double finishingProgress = .99;

  final MovieJobStatus status;

  /// The movie asked for; null when idle.
  final MovieJobRequest? request;

  /// The clips the movie joins, in play order. One that turns out not to be
  /// readable stays listed until the movie is made ([skippedClips]).
  final List<ClipRef> clips;

  /// The index in [clips] of the clip in hand (being prepared, then being
  /// joined: the join starts over from the first); null before the first and
  /// once every clip is done.
  final int? currentIndex;

  /// How many clips are done, the first [processed] of [clips]: prepared,
  /// or joined, whichever got further. Never goes back.
  final int processed;

  /// 0 to 1 over the whole job, never backwards: the clips done, or the joined
  /// share of the movie's length, whichever is further; at most
  /// [finishingProgress] until the movie is saved.
  final double progress;

  /// The movie made ([MovieJobStatus.done]).
  final MovieEntry? movie;

  final MovieJobFailure? failure;

  /// The bytes to free before the movie fits ([MovieJobFailure.noSpace]);
  /// null when not known.
  final int? spaceShortfall;

  /// How many clips were left out because they cannot be read: of the movie
  /// made ([MovieJobStatus.done], when [clips] no longer lists them), or of the
  /// one left with too few ([MovieJobFailure.notEnoughClips]).
  final int skippedClips;

  /// How many clips the movie made ([MovieJobStatus.done]) left out because
  /// their file says they are private, which the library learnt only then (the
  /// confirmation had counted them).
  final int leftOutPrivateClips;

  /// The clip being processed; null before the first and once every clip
  /// is done.
  ClipRef? get currentClip {
    final int? index = currentIndex;
    return index == null || index < 0 || index >= clips.length
        ? null
        : clips[index];
  }

  /// Whether a movie is being made (a new one can't start).
  bool get isRunning => switch (status) {
    MovieJobStatus.preparing ||
    MovieJobStatus.rendering ||
    MovieJobStatus.finishing ||
    MovieJobStatus.cancelling => true,
    MovieJobStatus.idle ||
    MovieJobStatus.done ||
    MovieJobStatus.failed ||
    MovieJobStatus.cancelled => false,
  };

  /// This state with the given fields changed; [clearCurrent] drops
  /// [currentIndex] (every clip done).
  MovieJobState copyWith({
    MovieJobStatus? status,
    List<ClipRef>? clips,
    int? currentIndex,
    bool clearCurrent = false,
    int? processed,
    double? progress,
    MovieEntry? movie,
    MovieJobFailure? failure,
    int? spaceShortfall,
    int? skippedClips,
    int? leftOutPrivateClips,
  }) => MovieJobState(
    status: status ?? this.status,
    request: request,
    clips: clips ?? this.clips,
    currentIndex: clearCurrent ? null : currentIndex ?? this.currentIndex,
    processed: processed ?? this.processed,
    progress: progress ?? this.progress,
    movie: movie ?? this.movie,
    failure: failure ?? this.failure,
    spaceShortfall: spaceShortfall ?? this.spaceShortfall,
    skippedClips: skippedClips ?? this.skippedClips,
    leftOutPrivateClips: leftOutPrivateClips ?? this.leftOutPrivateClips,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    request,
    clips,
    currentIndex,
    processed,
    progress,
    movie,
    failure,
    spaceShortfall,
    skippedClips,
    leftOutPrivateClips,
  ];
}
