import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/movie_player_cubit.dart';

import '../../../../support/support.dart';
import '../../support/fake_movie_repository.dart';

/// Three clips of a second and a half each.
const List<MovieChapter> _chapters = <MovieChapter>[
  MovieChapter(startMs: 0, endMs: 1500, title: 'Aug 1, 2026'),
  MovieChapter(startMs: 1500, endMs: 3000, title: 'Aug 2, 2026 · Berlin'),
  MovieChapter(startMs: 3000, endMs: 4500, title: 'Aug 3, 2026'),
];

/// A movie made by this version, with its chapters.
final MovieEntry _chaptered = MovieEntry(
  fileName: 'OSD-Movie-3-2024-01-03.mp4',
  title: 'Movie 3',
  profile: null,
  clipCount: 3,
  from: null,
  to: null,
  createdAt: DateTime(2024, 1, 3),
  durationMs: 4500,
  chapters: _chapters,
);

void main() {
  late FakeMovieRepository movies;
  late FakeWakelockGateway wakelock;
  late MemoryLogSink sink;

  setUp(() {
    movies = FakeMovieRepository(
      movies: <MovieEntry>[testMovie(2), testMovie(1)],
    );
    wakelock = FakeWakelockGateway();
    sink = MemoryLogSink();
  });

  Future<MoviePlayerCubit> open(String file) async {
    final MoviePlayerCubit cubit = MoviePlayerCubit(
      file: file,
      movies: movies,
      wakelock: wakelock,
      logger: memoryLogger(sink),
    );
    addTearDown(cubit.close);
    await pumpEventQueue();
    return cubit;
  }

  test('finds the movie it plays, for its title and shape; a movie no longer '
      'in Movies/ (deleted from the gallery) or in a folder that cannot be '
      'read (logged) cannot be played', () async {
    final MoviePlayerCubit cubit = await open(testMovie(1).fileName);
    expect(cubit.state.status, MoviePlayerStatus.ready);
    expect(cubit.state.movie, testMovie(1));

    final MoviePlayerCubit deleted = await open('OSD-Movie-9-2024-01-09.mp4');
    expect(deleted.state.status, MoviePlayerStatus.missing);
    expect(deleted.state.movie, isNull);

    movies.failNextList = true;
    final MoviePlayerCubit unreadable = await open(testMovie(1).fileName);
    expect(unreadable.state.status, MoviePlayerStatus.missing);
    expect(sink.lines.last, contains('[WARNING]'));
  });

  test('a movie plays with sound and the toggle mutes and unmutes it; the '
      'screen stays on while it plays, and may sleep once it pauses or the '
      'player closes', () async {
    final MoviePlayerCubit cubit = await open(testMovie(1).fileName);
    expect(cubit.state.muted, isFalse);
    cubit.toggleSound();
    expect(cubit.state.muted, isTrue);
    expect(cubit.state.movie, testMovie(1));
    cubit.toggleSound();
    expect(cubit.state.muted, isFalse);

    cubit.playingChanged(playing: true);
    await pumpEventQueue();
    expect(wakelock.enabled, isTrue);

    cubit
      ..playingChanged(playing: true)
      ..playingChanged(playing: false);
    await pumpEventQueue();
    expect(wakelock.enabled, isFalse);

    cubit.playingChanged(playing: true);
    await pumpEventQueue();
    await cubit.close();
    expect(wakelock.enabled, isFalse);
  });

  test('the chapter playing follows the playback, changing only when it '
      'crosses into another chapter (forward or back); a chapter tap seeks '
      'the player to its start and makes it current at once; a movie made '
      'by an older install has no chapters', () async {
    movies.movies.add(_chaptered);
    final MoviePlayerCubit cubit = await open(_chaptered.fileName);
    expect(cubit.state.chapters, _chapters);
    expect(cubit.state.currentChapter, _chapters[0]);

    final List<MoviePlayerState> emitted = <MoviePlayerState>[];
    final StreamSubscription<MoviePlayerState> states = cubit.stream.listen(
      emitted.add,
    );
    addTearDown(states.cancel);
    cubit
      ..positionChanged(const Duration(milliseconds: 700))
      ..positionChanged(const Duration(milliseconds: 1499));
    await pumpEventQueue();
    expect(emitted, isEmpty);

    cubit.positionChanged(const Duration(milliseconds: 1500));
    await pumpEventQueue();
    expect(cubit.state.currentChapter, _chapters[1]);
    expect(emitted, hasLength(1));

    cubit.positionChanged(const Duration(milliseconds: 4000));
    expect(cubit.state.currentChapter, _chapters[2]);
    cubit.positionChanged(const Duration(milliseconds: 200));
    expect(cubit.state.currentChapter, _chapters[0]);

    final List<Duration> seeks = <Duration>[];
    cubit
      ..attachPlayback(seekTo: seeks.add)
      ..seekToChapter(_chapters[2]);
    expect(seeks, <Duration>[const Duration(milliseconds: 3000)]);
    expect(cubit.state.currentChapter, _chapters[2]);

    final MoviePlayerCubit older = await open(testMovie(1).fileName);
    expect(older.state.chapters, isEmpty);
    older.positionChanged(const Duration(seconds: 1));
    expect(older.state.currentChapter, isNull);
  });
}
