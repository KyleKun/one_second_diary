import 'dart:async';
import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/share_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/movies/data/movie_audio.dart';
import 'package:one_second_diary/features/movies/data/movie_repository.dart';
import 'package:one_second_diary/features/movies/data/movie_tag_reader.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/domain/movie_listing.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/my_movies_state.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/setting.dart';

/// My movies, its profile filter, its selection mode and rename.
class MyMoviesCubit extends Cubit<MyMoviesState> {
  MyMoviesCubit({
    required this._movies,
    required this._tags,
    required this._share,
    required this._paths,
    required this._largeView,
    required this._logger,
    this._audio,
  }) : super(MyMoviesState.loading(largeView: _largeView.value)) {
    unawaited(load());
  }

  final MovieRepository _movies;
  final MovieTagReader _tags;
  final ShareGateway _share;
  final AppPaths _paths;

  /// Turns a movie's music off or on; without it the action does nothing.
  final MovieAudio? _audio;

  /// The view picked last (`SettingsRepository.moviesLargeView`).
  final Setting<bool> _largeView;
  final AppLogger _logger;

  static const String _tag = 'MOVIES';

  /// Bumped by every [load]: an older listing's tag reading stops.
  int _generation = 0;

  /// Lists the movies (again, after a failure).
  Future<void> load() async {
    final int generation = ++_generation;
    if (state.status == MyMoviesStatus.failed) {
      emit(MyMoviesState.loading(largeView: state.largeView));
    }
    final MovieListing listing;
    try {
      listing = await _movies.listing();
    } on Exception catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not list the movies',
        error: error,
        stackTrace: stackTrace,
      );
      if (!isClosed) {
        emit(
          MyMoviesState(
            status: MyMoviesStatus.failed,
            largeView: state.largeView,
          ),
        );
      }
      return;
    }
    if (isClosed || generation != _generation) return;
    emit(
      state.copyWith(
        status: MyMoviesStatus.ready,
        movies: listing.movies,
        selected: const <String>{},
      ),
    );
    await _readTags(listing, generation);
  }

  /// Reads the tags of [listing]'s unindexed movies, newest first, and
  /// shows each as read, unless the user renamed or deleted it meanwhile.
  Future<void> _readTags(MovieListing listing, int generation) async {
    for (final MovieEntry listed in listing.movies) {
      if (!listing.unindexed.contains(listed.fileName)) continue;
      final MovieEntry read = await _tags.read(listed);
      if (isClosed || generation != _generation) return;
      final int at = state.movies.indexOf(listed);
      if (at < 0 || read == listed) continue;
      emit(state.copyWith(movies: _replacedAt(at, read)));
    }
  }

  /// Shows the movies of [profiles] only (null among them: the movies that name
  /// no profile); empty shows every movie.
  void setProfileFilter(Set<ProfileKey?> profiles) {
    if (profiles.length == state.profileFilter.length &&
        state.profileFilter.containsAll(profiles)) {
      return;
    }
    final MyMoviesState filtered = state.copyWith(
      profileFilter: Set<ProfileKey?>.unmodifiable(profiles),
    );
    final Set<String> visible = <String>{
      for (final MovieEntry movie in filtered.visibleMovies) movie.fileName,
    };
    emit(
      filtered.copyWith(
        selected: <String>{
          for (final String file in state.selected)
            if (visible.contains(file)) file,
        },
      ),
    );
  }

  /// Shows every movie again.
  void clearProfileFilter() => setProfileFilter(const <ProfileKey?>{});

  /// A long press: [movie] is selected (selection mode starts).
  void select(MovieEntry movie) => emit(
    state.copyWith(selected: <String>{...state.selected, movie.fileName}),
  );

  /// A tap in selection mode: [movie] is selected or unselected.
  void toggle(MovieEntry movie) => emit(
    state.copyWith(
      selected: state.selected.contains(movie.fileName)
          ? (<String>{...state.selected}..remove(movie.fileName))
          : <String>{...state.selected, movie.fileName},
    ),
  );

  /// The bar's toggle: the movies one large picture a row ([large]), or the
  /// grid; remembered for the next visit.
  Future<void> showLargeView({required bool large}) async {
    if (large == state.largeView) return;
    emit(state.copyWith(largeView: large));
    try {
      await _largeView.set(large);
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not remember the movies view',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Close, or back: selection mode ends.
  void clearSelection() => emit(state.copyWith(selected: const <String>{}));

  /// Gives the one movie selected the title [title], then leaves selection.
  Future<bool> rename(String title) async {
    final List<MovieEntry> selected = state.selectedMovies;
    if (selected.length != 1 || title.trim().isEmpty) return false;
    final MovieEntry movie = selected.single;
    final MovieEntry renamed;
    try {
      renamed = await _movies.rename(movie: movie, title: title);
    } on AppException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not rename ${movie.fileName}',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
    if (isClosed) return true;
    final int at = state.movies.indexWhere(
      (MovieEntry shown) => shown.fileName == movie.fileName,
    );
    emit(
      state.copyWith(
        movies: at < 0 ? state.movies : _replacedAt(at, renamed),
        selected: const <String>{},
      ),
    );
    return true;
  }

  /// Deletes the movies selected (the dialog asked), then leaves selection
  /// and says how many went, or that the phone refused one (which stays).
  Future<void> deleteSelected() async {
    final List<MovieEntry> targets = state.selectedMovies;
    if (targets.isEmpty || state.deleting) return;
    emit(state.copyWith(deleting: true));
    final Set<String> gone = <String>{};
    bool refused = false;
    for (final MovieEntry movie in targets) {
      try {
        await _movies.delete(movie);
        gone.add(movie.fileName);
      } on AppException catch (error, stackTrace) {
        refused = true;
        _logger.warning(
          _tag,
          'Could not delete ${movie.fileName}',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    if (isClosed) return;
    emit(
      state
          .copyWith(
            movies: _without(gone),
            selected: const <String>{},
            deleting: false,
          )
          .saying(
            refused
                ? const MovieDeleteFailedNotice()
                : MoviesDeletedNotice(gone.length),
          ),
    );
  }

  /// Opens the system share sheet with the files of the movies selected,
  /// anchored to [origin] (the button, which iPad needs). Selection stays.
  Future<void> shareSelected({Rect? origin}) async {
    final List<MovieEntry> targets = state.selectedMovies;
    if (targets.isEmpty || state.sharing) return;
    emit(state.copyWith(sharing: true));
    final List<MovieEntry> present = <MovieEntry>[];
    final Set<String> gone = <String>{};
    for (final MovieEntry movie in targets) {
      if (await _movies.exists(movie)) {
        present.add(movie);
      } else {
        gone.add(movie.fileName);
      }
    }
    if (present.isNotEmpty) {
      await _share.shareFiles(<String>[
        for (final MovieEntry movie in present)
          '${_paths.movies}${movie.fileName}',
      ], origin: origin);
    }
    if (isClosed) return;
    final MyMoviesState shared = state.copyWith(
      sharing: false,
      movies: _without(gone),
      selected: <String>{...state.selected}..removeAll(gone),
    );
    emit(gone.isEmpty ? shared : shared.saying(const MovieFileMissingNotice()));
  }

  /// Turns the music of the one movie selected off when it plays, on when it
  /// does not (`MovieAudio.toggle`), then says so; selection stays.
  Future<void> toggleMusic() async {
    final MovieEntry? movie = state.musicMovie;
    final MovieAudio? audio = _audio;
    if (movie == null || audio == null || state.swappingMusic) return;
    emit(state.copyWith(swappingMusic: true));
    MovieEntry? toggled;
    try {
      toggled = await audio.toggle(movie);
    } on Object catch (error, stackTrace) {
      // MovieAudio logged its own failures; a file or platform error is
      // not an AppException and must not leave the action dead.
      _logger.warning(
        _tag,
        'Could not change the sound of ${movie.fileName}',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (isClosed) return;
    if (toggled == null) {
      emit(
        state
            .copyWith(swappingMusic: false)
            .saying(const MovieMusicSwapFailedNotice()),
      );
      return;
    }
    final int at = state.movies.indexWhere(
      (MovieEntry shown) => shown.fileName == movie.fileName,
    );
    emit(
      state
          .copyWith(
            swappingMusic: false,
            movies: at < 0 ? state.movies : _replacedAt(at, toggled),
          )
          .saying(MovieMusicSwappedNotice(on: toggled.musicOn ?? false)),
    );
  }

  /// Whether [movie] can be played: false when its file went from the gallery
  /// since it was listed (it then leaves the list, and the user is told).
  Future<bool> canPlay(MovieEntry movie) async {
    if (await _movies.exists(movie)) return true;
    if (!isClosed) {
      emit(
        state
            .copyWith(movies: _without(<String>{movie.fileName}))
            .saying(const MovieFileMissingNotice()),
      );
    }
    return false;
  }

  List<MovieEntry> _replacedAt(int at, MovieEntry movie) =>
      List<MovieEntry>.unmodifiable(
        List<MovieEntry>.of(state.movies)..[at] = movie,
      );

  List<MovieEntry> _without(Set<String> gone) => gone.isEmpty
      ? state.movies
      : List<MovieEntry>.unmodifiable(<MovieEntry>[
          for (final MovieEntry movie in state.movies)
            if (!gone.contains(movie.fileName)) movie,
        ]);
}
