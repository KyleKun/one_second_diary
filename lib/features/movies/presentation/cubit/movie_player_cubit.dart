import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/core/platform/wakelock_gateway.dart';
import 'package:one_second_diary/features/movies/data/movie_repository.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';

/// Where the movie player is.
enum MoviePlayerStatus {
  /// Finding the movie (its poster and player load meanwhile).
  loading,

  /// Found: its title, clips and shape are known.
  ready,

  /// Not in `Movies/` any more (deleted from the gallery), or `Movies/`
  /// can't be read: "Can't play this video".
  missing,
}

/// The movie player's state: the movie at [file].
final class MoviePlayerState extends Equatable {
  const MoviePlayerState({
    required this.file,
    required this.status,
    this.movie,
    this.muted = false,
    this.currentChapter,
  });

  /// Its path in `Movies/`.
  final String file;
  final MoviePlayerStatus status;

  /// What My movies knows about it; null until found.
  final MovieEntry? movie;

  /// Whether the sound is off (a movie opens with it on).
  final bool muted;

  /// The chapter (the clip) playing now; null until the movie is found, and
  /// always for a movie without chapters (made by an older install).
  final MovieChapter? currentChapter;

  /// The movie's chapters, one per clip in its order; empty until it is
  /// found, and for a movie made by an older install.
  List<MovieChapter> get chapters => movie?.chapters ?? const <MovieChapter>[];

  MoviePlayerState copyWith({
    MoviePlayerStatus? status,
    MovieEntry? movie,
    bool? muted,
    MovieChapter? currentChapter,
  }) => MoviePlayerState(
    file: file,
    status: status ?? this.status,
    movie: movie ?? this.movie,
    muted: muted ?? this.muted,
    currentChapter: currentChapter ?? this.currentChapter,
  );

  @override
  List<Object?> get props => <Object?>[
    file,
    status,
    movie,
    muted,
    currentChapter,
  ];
}

/// The movie player (`/movies/play?file=`, always dark): finds the movie it
/// plays (its title, clip count, shape and chapters), holds the sound toggle,
/// follows the playback through its chapters, and keeps the screen on while it
/// plays, so a nine-minute movie never goes dark halfway (the movie job may
/// hold the screen too: `SharedWakelock`).
class MoviePlayerCubit extends Cubit<MoviePlayerState> {
  MoviePlayerCubit({
    required String file,
    required this._movies,
    required this._wakelock,
    required this._logger,
  }) : super(MoviePlayerState(file: file, status: MoviePlayerStatus.loading)) {
    unawaited(_find());
  }

  final MovieRepository _movies;
  final WakelockGateway _wakelock;
  final AppLogger _logger;

  static const String _tag = 'MOVIES';

  /// Whether this player holds the screen on.
  bool _holding = false;

  /// Where the playback was last reported, in milliseconds.
  int _positionMs = 0;

  /// The player's seek, once the page lends it.
  ValueChanged<Duration>? _seekTo;

  Future<void> _find() async {
    MovieEntry? movie;
    try {
      movie = (await _movies.list())
          .where((MovieEntry entry) => entry.fileName == state.file)
          .firstOrNull;
    } on Exception catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not find ${state.file} to play it',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        status: movie == null
            ? MoviePlayerStatus.missing
            : MoviePlayerStatus.ready,
        movie: movie,
        currentChapter: movie?.chapterAt(_positionMs),
      ),
    );
  }

  /// The sound toggle: mutes the movie, or unmutes it.
  void toggleSound() => emit(state.copyWith(muted: !state.muted));

  /// Lends the player's seek to [seekToChapter].
  void attachPlayback({required ValueChanged<Duration> seekTo}) =>
      _seekTo = seekTo;

  /// The playback is at [position]: the current chapter follows, emitted only
  /// when the playback crosses into another one (the page calls this every
  /// frame while the movie plays).
  void positionChanged(Duration position) {
    if (isClosed) return;
    _positionMs = position.inMilliseconds;
    final MovieChapter? current = state.currentChapter;
    if (current != null &&
        _positionMs >= current.startMs &&
        _positionMs < current.endMs) {
      return;
    }
    final MovieChapter? next = state.movie?.chapterAt(_positionMs);
    if (next == null || next == current) return;
    emit(state.copyWith(currentChapter: next));
  }

  /// Jumps to the start of [chapter]; the movie plays on if it was playing,
  /// and stays paused if it was paused. The chapter is current at once.
  void seekToChapter(MovieChapter chapter) {
    if (isClosed) return;
    _seekTo?.call(Duration(milliseconds: chapter.startMs));
    _positionMs = chapter.startMs;
    if (state.currentChapter != chapter) {
      emit(state.copyWith(currentChapter: chapter));
    }
  }

  /// The movie started or stopped playing: the screen stays on while it
  /// plays.
  void playingChanged({required bool playing}) {
    if (playing == _holding) return;
    _holding = playing;
    unawaited(playing ? _wakelock.enable() : _wakelock.disable());
  }

  @override
  Future<void> close() async {
    if (_holding) {
      _holding = false;
      await _wakelock.disable();
    }
    return super.close();
  }
}
