import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/movie_render_event.dart';
import 'package:one_second_diary/core/platform/free_space_gateway.dart';
import 'package:one_second_diary/core/platform/wakelock_gateway.dart';
import 'package:one_second_diary/core/storage/storage_space.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_backfill.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/movies/data/movie_builder.dart';
import 'package:one_second_diary/features/movies/domain/movie_build_event.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/domain/movie_space.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_event.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_state.dart';

/// The movie being made, app-scoped: it goes on while the user leaves the
/// Create movie flow or the app, and one movie runs at a time. It keeps the
/// screen awake and pauses the clip metadata backfill while the movie is made,
/// and cancelling stops the builder and deletes the job's files.
class MovieJobBloc extends Bloc<MovieJobEvent, MovieJobState> {
  MovieJobBloc({
    required this._builder,
    required this._wakelock,
    required this._backfill,
    required this._freeSpace,
    required this._logger,
  }) : super(const MovieJobState.idle()) {
    on<MovieJobStarted>(_start);
    on<MovieJobCancelled>(_cancel);
    on<MovieJobDismissed>(_dismiss);
  }

  final MovieBuilder _builder;
  final WakelockGateway _wakelock;
  final ClipMetadataBackfill _backfill;
  final FreeSpaceGateway _freeSpace;
  final AppLogger _logger;

  static const String _tag = 'CREATE MOVIE';

  /// The running job's cancel.
  CancelToken? _cancelToken;

  Future<void> _start(
    MovieJobStarted event,
    Emitter<MovieJobState> emit,
  ) async {
    if (state.isRunning) return;
    final CancelToken token = CancelToken();
    _cancelToken = token;
    emit(
      MovieJobState(status: MovieJobStatus.preparing, request: event.request),
    );
    _backfill.pause();
    await _wakelock.enable();
    try {
      await emit.forEach<MovieBuildEvent>(
        _builder.build(
          source: event.request.source,
          profile: event.request.profile,
          format: event.request.format,
          title: event.request.title,
          includePrivate: event.request.includePrivate,
          transition: event.request.transition,
          upgradeOlderClips: event.request.upgradeOlderClips,
          music: event.request.music,
          cancelToken: token,
        ),
        onData: _next,
      );
    } on CancelledException {
      emit(state.copyWith(status: MovieJobStatus.cancelled));
    } on ArgumentError {
      // MovieBuilder logged the "Insufficient videos" line.
      emit(
        state.copyWith(
          status: MovieJobStatus.failed,
          failure: MovieJobFailure.notEnoughClips,
        ),
      );
    } on NotEnoughClipsException catch (error) {
      // Too few clips could be read; MovieBuilder logged it.
      emit(
        state.copyWith(
          status: MovieJobStatus.failed,
          failure: MovieJobFailure.notEnoughClips,
          skippedClips: error.skipped,
        ),
      );
    } on Object catch (error, stackTrace) {
      // MovieBuilder logged what failed; this says where it surfaced.
      _logger.warning(
        _tag,
        'The movie job failed',
        error: error,
        stackTrace: stackTrace,
      );
      emit(
        StorageSpace.isOutOfSpace(error)
            ? state.copyWith(
                status: MovieJobStatus.failed,
                failure: MovieJobFailure.noSpace,
                spaceShortfall: await _shortfall(event.request),
              )
            : state.copyWith(
                status: MovieJobStatus.failed,
                failure: MovieJobFailure.failed,
              ),
      );
    } finally {
      if (identical(_cancelToken, token)) _cancelToken = null;
      _backfill.resume();
      await _wakelock.disable();
    }
  }

  /// How much more the movie needs than the phone has free now that the builder
  /// deleted what it made; null when the phone doesn't say, or when the
  /// estimate says it fits (it didn't: other apps write too).
  Future<int?> _shortfall(MovieJobRequest request) async =>
      MovieSpace.shortfall(
        needed: MovieSpace.neededFor(request.clipBytes),
        free: await _freeSpace.freeBytes(),
      );

  MovieJobState _next(MovieBuildEvent event) => switch (event) {
    MovieBuildStarted(:final clips) => state.copyWith(clips: clips),
    MovieBuildProgress(
      progress: MoviePreparing(:final int index, :final int total),
    ) =>
      _progressed(index: index, fraction: total == 0 ? 0 : index / total),
    MovieBuildProgress(
      progress: MovieConcatenating(
        :final double fraction,
        :final int currentIndex,
      ),
    ) =>
      _progressed(
        index: currentIndex,
        fraction: math.max(fraction, _share(currentIndex)),
      ),
    // The builder never reports a MovieCompleted as progress.
    MovieBuildProgress() => state,
    MovieBuildFinishing() when state.status == MovieJobStatus.cancelling =>
      state,
    MovieBuildFinishing() => state.copyWith(
      status: MovieJobStatus.finishing,
      clearCurrent: true,
      processed: state.clips.length,
      progress: MovieJobState.finishingProgress,
    ),
    // Made before a cancel could stop it: the movie is kept.
    MovieBuilt(:final movie, :final skipped, :final leftOutPrivate) => _built(
      movie,
      skipped: skipped,
      leftOutPrivate: leftOutPrivate,
    ),
  };

  /// [movie] is made without the [skipped] clips and the [leftOutPrivate] ones,
  /// which leave the list: it is the movie's clips again (the created page
  /// shows the first one).
  MovieJobState _built(
    MovieEntry movie, {
    required List<ClipRef> skipped,
    required List<ClipRef> leftOutPrivate,
  }) {
    final List<ClipRef> joined = skipped.isEmpty && leftOutPrivate.isEmpty
        ? state.clips
        : <ClipRef>[
            for (final ClipRef clip in state.clips)
              if (!skipped.contains(clip) && !leftOutPrivate.contains(clip))
                clip,
          ];
    return state.copyWith(
      status: MovieJobStatus.done,
      clearCurrent: true,
      clips: joined,
      processed: joined.length,
      movie: movie,
      skippedClips: skipped.length,
      leftOutPrivateClips: leftOutPrivate.length,
      progress: 1,
    );
  }

  /// Clip [index] is in hand, and [fraction] of the job is done.
  MovieJobState _progressed({required int index, required double fraction}) {
    if (state.status == MovieJobStatus.cancelling) return state;
    return state.copyWith(
      status: MovieJobStatus.rendering,
      currentIndex: index,
      processed: math.max(state.processed, index),
      progress: math.max(
        state.progress,
        math.min(fraction, MovieJobState.finishingProgress),
      ),
    );
  }

  /// The share of the clips before clip [index].
  double _share(int index) =>
      state.clips.isEmpty ? 0 : index / state.clips.length;

  void _cancel(MovieJobCancelled event, Emitter<MovieJobState> emit) {
    final CancelToken? token = _cancelToken;
    if (token == null ||
        state.status == MovieJobStatus.finishing ||
        state.status == MovieJobStatus.cancelling) {
      return;
    }
    emit(state.copyWith(status: MovieJobStatus.cancelling));
    token.cancel();
  }

  void _dismiss(MovieJobDismissed event, Emitter<MovieJobState> emit) {
    if (!state.isRunning) emit(const MovieJobState.idle());
  }

  /// Stops a running movie and closes. Safe to call twice: the app root's
  /// provider and the container both close the app-scoped job.
  @override
  Future<void> close() {
    _cancelToken?.cancel();
    if (isClosed) return Future<void>.value();
    return super.close();
  }
}
