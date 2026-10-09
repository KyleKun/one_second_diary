import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/features/movies/data/movie_repository.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/domain/movie_listing.dart';

/// A [MovieRepository] over an in-memory list of [movies] (newest first),
/// which the test changes.
///
/// - [failNextList] makes the next listing throw as a folder the phone
///   can't read does; [holdList] keeps listings pending until
///   [releaseList].
/// - [unindexed] are the movies the index knows nothing about.
/// - [rename] and [delete] change [movies]; the paths in [refuseRename] /
///   [refuseDelete] are refused as the index or the gallery would.
/// - [missing] are movies whose file is gone ([exists]).
class FakeMovieRepository extends Fake implements MovieRepository {
  FakeMovieRepository({List<MovieEntry>? movies})
    : movies = movies ?? <MovieEntry>[];

  final List<MovieEntry> movies;
  final Set<String> unindexed = <String>{};
  final Set<String> refuseRename = <String>{};
  final Set<String> refuseDelete = <String>{};
  final Set<String> missing = <String>{};

  /// The paths deleted, in order.
  final List<String> deleted = <String>[];

  bool failNextList = false;
  bool holdList = false;
  Completer<void>? _listGate;

  /// Lets a held listing answer.
  void releaseList() {
    holdList = false;
    _listGate?.complete();
    _listGate = null;
  }

  @override
  Future<List<MovieEntry>> list() async => (await listing()).movies;

  @override
  Future<MovieListing> listing() async {
    if (holdList) await (_listGate ??= Completer<void>()).future;
    if (failNextList) {
      failNextList = false;
      throw const FileSystemException('Movies/ could not be read');
    }
    return MovieListing(
      movies: List<MovieEntry>.unmodifiable(movies),
      unindexed: Set<String>.unmodifiable(unindexed),
    );
  }

  @override
  Future<MovieEntry> rename({
    required MovieEntry movie,
    required String title,
  }) async {
    if (refuseRename.contains(movie.fileName)) {
      throw const StorageException('Could not save the movie index');
    }
    final MovieEntry renamed = movie.withTitle(title.trim());
    final int at = movies.indexWhere(
      (MovieEntry m) => m.fileName == movie.fileName,
    );
    if (at >= 0) movies[at] = renamed;
    unindexed.remove(movie.fileName);
    return renamed;
  }

  /// Every [update], in order.
  final List<MovieEntry> updated = <MovieEntry>[];

  @override
  Future<void> update(MovieEntry movie) async {
    if (refuseRename.contains(movie.fileName)) {
      throw const StorageException('Could not save the movie index');
    }
    updated.add(movie);
    final int at = movies.indexWhere(
      (MovieEntry m) => m.fileName == movie.fileName,
    );
    if (at >= 0) movies[at] = movie;
  }

  @override
  Future<void> delete(MovieEntry movie) async {
    if (refuseDelete.contains(movie.fileName)) {
      throw const MediaStoreException('Could not delete the movie');
    }
    movies.removeWhere((MovieEntry m) => m.fileName == movie.fileName);
    deleted.add(movie.fileName);
  }

  @override
  Future<bool> exists(MovieEntry movie) async =>
      !missing.contains(movie.fileName);
}

/// A movie made on [number] January 2024, without the index's facts.
MovieEntry testMovie(int number) => MovieEntry(
  fileName: 'OSD-Movie-$number-2024-01-0$number.mp4',
  title: 'Movie $number',
  profile: null,
  clipCount: null,
  from: null,
  to: null,
  createdAt: DateTime(2024, 1, number),
  durationMs: null,
);
