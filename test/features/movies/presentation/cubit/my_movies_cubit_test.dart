import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/my_movies_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/my_movies_state.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/setting.dart';

import '../../../../support/support.dart';
import '../../support/fake_movie_audio.dart';
import '../../support/fake_movie_repository.dart';
import '../../support/fake_movie_tag_reader.dart';
import '../../support/my_movies_world.dart' show kids, madeMovie;

void main() {
  late AppPaths paths;
  late FakeMovieRepository movies;
  late FakeMovieTagReader tags;
  late FakeShareGateway share;
  late FakeMovieAudio audio;
  late MemoryLogSink sink;

  setUp(() async {
    paths = await createTestPaths();
    movies = FakeMovieRepository(
      movies: <MovieEntry>[testMovie(3), testMovie(2), testMovie(1)],
    );
    tags = FakeMovieTagReader();
    share = FakeShareGateway();
    audio = FakeMovieAudio();
    sink = MemoryLogSink();
  });

  /// The view remembered (`moviesLargeView`).
  bool storedLargeView = false;
  late final Setting<bool> largeView = Setting<bool>(
    read: () => storedLargeView,
    write: (bool large) async => storedLargeView = large,
  );

  MyMoviesCubit open() => MyMoviesCubit(
    movies: movies,
    tags: tags,
    share: share,
    paths: paths,
    largeView: largeView,
    logger: memoryLogger(sink),
    audio: audio,
  );

  /// The cubit, once the movies are listed.
  Future<MyMoviesCubit> opened() async {
    final MyMoviesCubit cubit = open();
    addTearDown(cubit.close);
    await pumpEventQueue();
    return cubit;
  }

  List<String> titlesOf(MyMoviesCubit cubit) =>
      cubit.state.movies.map((MovieEntry movie) => movie.title).toList();

  group('the list', () {
    test('loads, then shows every movie as the repository lists them, newest '
        'first; a folder that cannot be read fails (logged), and Try again '
        'lists it', () async {
      movies.holdList = true;
      final MyMoviesCubit cubit = open();
      addTearDown(cubit.close);
      expect(cubit.state.status, MyMoviesStatus.loading);
      movies.releaseList();
      await pumpEventQueue();
      expect(cubit.state.status, MyMoviesStatus.ready);
      expect(titlesOf(cubit), <String>['Movie 3', 'Movie 2', 'Movie 1']);

      movies.failNextList = true;
      await cubit.load();
      expect(cubit.state.status, MyMoviesStatus.failed);
      expect(sink.lines.last, contains('[WARNING]'));
      await cubit.load();
      expect(cubit.state.status, MyMoviesStatus.ready);
      expect(cubit.state.movies, hasLength(3));
    });

    test('movies the index knows nothing about have their tags read one at a '
        'time, newest first, each shown as soon as it is read (decision O9); '
        'one renamed or deleted meanwhile stays as the user left it', () async {
      movies.unindexed.addAll(<String>[
        testMovie(1).fileName,
        testMovie(3).fileName,
      ]);
      tags
        ..hold = true
        ..answers[testMovie(3).fileName] = testMovie(3).withTitle('2025')
        ..answers[testMovie(1).fileName] = testMovie(1).withTitle('Japan');
      final MyMoviesCubit cubit = await opened();
      expect(tags.reads, <String>[testMovie(3).fileName]);

      tags.releaseOne();
      await pumpEventQueue();
      expect(titlesOf(cubit), <String>['2025', 'Movie 2', 'Movie 1']);
      expect(tags.reads, <String>[
        testMovie(3).fileName,
        testMovie(1).fileName,
      ]);

      tags.releaseOne();
      await pumpEventQueue();
      expect(titlesOf(cubit), <String>['2025', 'Movie 2', 'Japan']);

      // A rename and a delete while the tags are read.
      {
        movies.unindexed.addAll(<String>[
          testMovie(3).fileName,
          testMovie(2).fileName,
        ]);
        tags
          ..hold = true
          ..answers[testMovie(3).fileName] = testMovie(3).withTitle('Tags 3')
          ..answers[testMovie(2).fileName] = testMovie(2).withTitle('Tags 2');
        final MyMoviesCubit cubit = await opened();

        cubit.select(cubit.state.movies.first);
        expect(await cubit.rename('Summer'), isTrue);
        tags.releaseOne();
        await pumpEventQueue();
        cubit.select(cubit.state.movies[1]);
        await cubit.deleteSelected();
        tags.releaseOne();
        await pumpEventQueue();

        expect(titlesOf(cubit), <String>['Summer', 'Movie 1']);
      }
    });
  });

  test('selection (M9): a long press selects the movie; a tap then toggles '
      'movies; unselecting the last one, or close, leaves selection', () async {
    final MyMoviesCubit cubit = await opened();
    final List<MovieEntry> shown = cubit.state.movies;
    expect(cubit.state.selecting, isFalse);

    cubit.select(shown[1]);
    expect(cubit.state.selected, <String>{shown[1].fileName});
    expect(cubit.state.selecting, isTrue);

    cubit
      ..toggle(shown[0])
      ..select(shown[2]);
    expect(cubit.state.selectedMovies, shown);

    cubit
      ..toggle(shown[0])
      ..toggle(shown[1]);
    expect(cubit.state.selectedMovies, <MovieEntry>[shown[2]]);

    cubit.toggle(shown[2]);
    expect(cubit.state.selecting, isFalse);

    cubit
      ..select(shown[0])
      ..toggle(shown[1])
      ..clearSelection();
    expect(cubit.state.selected, isEmpty);
  });

  test('rename (M10) renames the one movie selected in place, then leaves '
      'selection; a refused rename says so to the dialog and changes '
      'nothing', () async {
    final MyMoviesCubit cubit = await opened();
    movies.refuseRename.add(testMovie(3).fileName);
    cubit.select(cubit.state.movies[1]);
    expect(await cubit.rename('  Summer in Japan '), isTrue);
    expect(titlesOf(cubit), <String>['Movie 3', 'Summer in Japan', 'Movie 1']);
    expect(cubit.state.selecting, isFalse);

    cubit.select(cubit.state.movies[0]);
    expect(await cubit.rename('Summer'), isFalse);
    expect(titlesOf(cubit), <String>['Movie 3', 'Summer in Japan', 'Movie 1']);
    expect(cubit.state.selected, <String>{testMovie(3).fileName});
  });

  test('delete removes the movies selected, leaves selection and says how '
      'many went, each time; one the phone refused stays and the failure is '
      'said (logged)', () async {
    final MyMoviesCubit cubit = await opened();
    cubit
      ..select(cubit.state.movies[0])
      ..toggle(cubit.state.movies[2]);
    await cubit.deleteSelected();
    expect(movies.deleted, <String>[
      testMovie(3).fileName,
      testMovie(1).fileName,
    ]);
    expect(titlesOf(cubit), <String>['Movie 2']);
    expect(cubit.state.selecting, isFalse);
    expect(cubit.state.notice, const MoviesDeletedNotice(2));
    expect(cubit.state.deleting, isFalse);
    final int first = cubit.state.noticeId;

    movies.refuseDelete.add(testMovie(2).fileName);
    cubit.select(cubit.state.movies[0]);
    await cubit.deleteSelected();
    expect(titlesOf(cubit), <String>['Movie 2']);
    expect(cubit.state.notice, const MovieDeleteFailedNotice());
    expect(sink.lines.last, contains('[WARNING]'));

    movies.refuseDelete.clear();
    cubit.select(cubit.state.movies[0]);
    await cubit.deleteSelected();
    expect(cubit.state.notice, const MoviesDeletedNotice(1));
    expect(cubit.state.noticeId, greaterThan(first));
  });

  test('share hands the files of the movies selected to the sheet, anchored '
      'to the button, and stays in selection; a movie still on the phone can '
      'be played; one deleted from the gallery meanwhile is neither shared '
      'nor played: it leaves the list and the user is told', () async {
    final MyMoviesCubit cubit = await opened();
    cubit
      ..select(cubit.state.movies[2])
      ..toggle(cubit.state.movies[0]);
    const Rect origin = Rect.fromLTWH(300, 40, 44, 44);

    await cubit.shareSelected(origin: origin);

    expect(share.sharedFiles, <List<String>>[
      <String>[
        '${paths.movies}${testMovie(3).fileName}',
        '${paths.movies}${testMovie(1).fileName}',
      ],
    ]);
    expect(share.lastOrigin, origin);
    expect(cubit.state.selected, hasLength(2));
    expect(cubit.state.sharing, isFalse);
    expect(await cubit.canPlay(cubit.state.movies[0]), isTrue);

    // Deleted from the gallery meanwhile.
    {
      final MyMoviesCubit cubit = await opened();
      movies.missing.addAll(<String>[
        testMovie(3).fileName,
        testMovie(1).fileName,
      ]);
      cubit
        ..select(cubit.state.movies[0])
        ..toggle(cubit.state.movies[1]);

      await cubit.shareSelected();
      expect(share.sharedFiles.last, <String>[
        '${paths.movies}${testMovie(2).fileName}',
      ]);
      expect(titlesOf(cubit), <String>['Movie 2', 'Movie 1']);
      expect(cubit.state.notice, const MovieFileMissingNotice());

      expect(await cubit.canPlay(cubit.state.movies[1]), isFalse);
      expect(titlesOf(cubit), <String>['Movie 2']);
      expect(cubit.state.notice, const MovieFileMissingNotice());
    }
  });

  group('the profile filter', () {
    const ProfileKey work = ProfileKey('Work');
    final MovieEntry kidsMovie = madeMovie(
      4,
      title: 'Kids 2025',
      profile: kids,
      day: 4,
    );
    final MovieEntry workMovie = madeMovie(
      3,
      title: 'Work',
      profile: work,
      day: 3,
    );
    final MovieEntry defaultMovie = madeMovie(2, title: 'Default', day: 2);
    final MovieEntry older = madeMovie(1, title: 'Older', profile: null);

    List<String> visibleTitles(MyMoviesCubit cubit) => cubit.state.visibleMovies
        .map((MovieEntry movie) => movie.title)
        .toList();

    setUp(() {
      movies.movies
        ..clear()
        ..addAll(<MovieEntry>[kidsMovie, workMovie, defaultMovie, older]);
    });

    test('keeps the movies of the profiles chosen, the ones that name no '
        'profile as a choice of their own; without a filter the list shown '
        'is the very list', () async {
      final MyMoviesCubit cubit = await opened();
      expect(cubit.state.isFiltered, isFalse);
      expect(identical(cubit.state.visibleMovies, cubit.state.movies), isTrue);
      expect(cubit.state.profileCounts, <MovieProfileCount>[
        const MovieProfileCount(profile: kids, count: 1),
        const MovieProfileCount(profile: work, count: 1),
        const MovieProfileCount(profile: ProfileKey.defaultProfile, count: 1),
        const MovieProfileCount(profile: null, count: 1),
      ]);

      cubit.setProfileFilter(<ProfileKey?>{kids, null});
      expect(cubit.state.isFiltered, isTrue);
      expect(visibleTitles(cubit), <String>['Kids 2025', 'Older']);
      expect(cubit.state.movies, hasLength(4));

      cubit.setProfileFilter(<ProfileKey?>{work});
      expect(visibleTitles(cubit), <String>['Work']);

      cubit.clearProfileFilter();
      expect(cubit.state.isFiltered, isFalse);
      expect(identical(cubit.state.visibleMovies, cubit.state.movies), isTrue);
    });

    test('selection works on the movies shown: a filter that hides a '
        'selected movie unselects it; a filter left with no movie (its last '
        'one deleted) says so until cleared', () async {
      final MyMoviesCubit cubit = await opened();
      cubit.select(workMovie);
      cubit.toggle(kidsMovie);
      expect(cubit.state.selectedMovies, <MovieEntry>[kidsMovie, workMovie]);

      cubit.setProfileFilter(<ProfileKey?>{kids, ProfileKey.defaultProfile});
      expect(cubit.state.selectedMovies, <MovieEntry>[kidsMovie]);
      cubit.toggle(defaultMovie);
      expect(cubit.state.selectedMovies, <MovieEntry>[kidsMovie, defaultMovie]);

      cubit.clearSelection();
      cubit.setProfileFilter(<ProfileKey?>{kids});
      cubit.select(kidsMovie);
      await cubit.deleteSelected();
      expect(cubit.state.noMatches, isTrue);
      expect(cubit.state.visibleMovies, isEmpty);
      expect(cubit.state.movies, hasLength(3));
      expect(cubit.state.profileCounts, hasLength(3));

      cubit.clearProfileFilter();
      expect(cubit.state.noMatches, isFalse);
      expect(visibleTitles(cubit), <String>['Work', 'Default', 'Older']);
    });
  });

  test(
    'music off/on (D28): the one movie selected with music is the action\'s; '
    'toggling swaps it in place, keeps the selection and says which plays; '
    'a failed swap says so and changes nothing; a movie without music has '
    'no action',
    () async {
      movies.movies[0] = testMovie(3).withMusicOn(on: true);
      final MyMoviesCubit cubit = await opened();
      expect(cubit.state.musicMovie, isNull);

      cubit.select(cubit.state.movies[1]);
      expect(cubit.state.musicMovie, isNull);
      await cubit.toggleMusic();
      expect(audio.toggled, isEmpty);

      cubit
        ..clearSelection()
        ..select(cubit.state.movies[0]);
      expect(cubit.state.musicMovie?.fileName, testMovie(3).fileName);
      await cubit.toggleMusic();
      expect(audio.toggled, hasLength(1));
      expect(cubit.state.movies[0].musicOn, isFalse);
      expect(cubit.state.selecting, isTrue);
      expect(cubit.state.swappingMusic, isFalse);
      expect(cubit.state.notice, const MovieMusicSwappedNotice(on: false));

      audio.failNext = true;
      await cubit.toggleMusic();
      expect(cubit.state.movies[0].musicOn, isFalse);
      expect(cubit.state.notice, const MovieMusicSwapFailedNotice());

      cubit.toggle(cubit.state.movies[1]);
      expect(cubit.state.musicMovie, isNull);
    },
  );
}
