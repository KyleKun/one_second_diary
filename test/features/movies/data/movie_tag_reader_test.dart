import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/movies/data/movie_index.dart';
import 'package:one_second_diary/features/movies/data/movie_tag_reader.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/domain/movie_tags.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../support/fake_movie_tag_source.dart';

/// How My movies lists a movie it knows only by its file.
MovieEntry _listed(String fileName, {String title = '2025-12-31'}) =>
    MovieEntry(
      fileName: fileName,
      title: title,
      profile: null,
      clipCount: null,
      from: null,
      to: null,
      createdAt: DateTime(2025, 12, 31, 21),
      durationMs: null,
    );

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late FakeMovieTagSource tags;
  late MovieIndex index;
  late MovieTagReader reader;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    tags = FakeMovieTagSource();
    index = MovieIndex(
      paths: paths,
      logger: memoryLogger(sink),
      clock: FakeClock(DateTime(2026, 9, 30)),
    );
    reader = MovieTagReader(
      source: tags,
      index: index,
      paths: paths,
      logger: memoryLogger(sink),
    );
  });

  test('a v3 movie found without its index entry (after a reinstall) gets '
      'back its title, profile, clips, days, tag filter, transition, music, '
      "duration, canvas and chapters from its tags (the engine's probe gives them), keeps its "
      'file date, and is recorded so it is read once (decisions O9, '
      'D25)', () async {
    const List<MovieChapter> chapters = <MovieChapter>[
      MovieChapter(startMs: 0, endMs: 1500, title: 'January 1, 2025'),
      MovieChapter(startMs: 1500, endMs: 3000, title: 'January 2, 2025'),
    ];
    tags.answers['${paths.movies}Trips/OSD-Movie-3-2025-12-31.mp4'] =
        const MovieTags(
          title: '2025',
          comment: 'profile=Kids',
          description:
              'clips=340;from=2025-01-01;to=2025-12-31'
              ';tags=kids,trip;without=work;transition=white;music=off',
          durationMs: 680000,
          width: 1080,
          height: 1920,
          chapters: chapters,
        );

    final MovieEntry movie = await reader.read(
      _listed('Trips/OSD-Movie-3-2025-12-31.mp4'),
    );

    expect(
      movie,
      MovieEntry(
        fileName: 'Trips/OSD-Movie-3-2025-12-31.mp4',
        title: '2025',
        profile: const ProfileKey('Kids'),
        clipCount: 340,
        from: LocalDay(2025, 1, 1),
        to: LocalDay(2025, 12, 31),
        createdAt: DateTime(2025, 12, 31, 21),
        durationMs: 680000,
        orientation: VideoOrientation.portrait,
        tags: <String>['kids', 'trip'],
        without: <String>['work'],
        chapters: chapters,
        transition: MovieTransition.fadeWhite,
        musicOn: false,
      ),
    );
    expect((await index.entries())['Trips/OSD-Movie-3-2025-12-31.mp4'], movie);

    // In the app, the engine's probe gives those tags.
    final FakeMediaEngine engine = FakeMediaEngine(
      scratchDir: paths.scratchDir,
    );
    engine.probes['/movies/a.mp4'] = const ClipProbe(
      durationMs: 4500,
      hasAudio: true,
      hasSubtitleStream: false,
      artist: null,
      album: null,
      comment: 'profile=Kids',
      locationTag: null,
      title: 'Kids · 2025',
      description: 'clips=340;from=2025-01-01;to=2025-12-31',
      width: 1920,
      height: 1080,
      codec: 'h264',
      fps: 30,
      chapters: chapters,
    );

    expect(
      await EngineMovieTagSource(engine: engine).tagsOf('/movies/a.mp4'),
      const MovieTags(
        title: 'Kids · 2025',
        comment: 'profile=Kids',
        description: 'clips=340;from=2025-01-01;to=2025-12-31',
        durationMs: 4500,
        width: 1920,
        height: 1080,
        chapters: chapters,
      ),
    );
  });

  test('a v1.x movie (no tags) keeps the title its name gives and gains its '
      'duration and canvas; one that cannot be probed is left as listed, '
      'logged and not recorded; an index that cannot be saved still gives '
      'the movie (logged)', () async {
    tags.answers['${paths.movies}OSD-Movie-2-2023-05-01.mp4'] = const MovieTags(
      durationMs: 90000,
      width: 1920,
      height: 1080,
    );
    final MovieEntry legacy = await reader.read(
      _listed('OSD-Movie-2-2023-05-01.mp4', title: '2023-05-01'),
    );
    expect(
      (legacy.title, legacy.profile, legacy.clipCount, legacy.durationMs),
      ('2023-05-01', null, null, 90000),
    );
    expect(legacy.orientation, VideoOrientation.landscape);

    final MovieEntry unprobed = _listed('OSD-Movie-5-2023-06-01.mp4');
    expect(await reader.read(unprobed), unprobed);
    expect((await index.entries()).keys, isNot(contains(unprobed.fileName)));
    expect(sink.lines.last, allOf(contains('[WARNING]'), contains('MOVIES')));

    tags.answers['${paths.movies}OSD-Movie-3-2025-12-31.mp4'] = const MovieTags(
      title: '2025',
    );
    final MovieTagReader refused = MovieTagReader(
      source: tags,
      index: _RefusingIndex(paths: paths, sink: sink),
      paths: paths,
      logger: memoryLogger(sink),
    );
    expect(
      (await refused.read(_listed('OSD-Movie-3-2025-12-31.mp4'))).title,
      '2025',
    );
    expect(sink.lines.last, contains('[WARNING]'));
  });

  test(
    'a movie the user renames while its tags are read or recorded keeps '
    'the new title, however the two interleave: the index entry wins',
    () async {
      final MovieEntry held = _listed('OSD-Movie-99-2023-05-01.mp4');
      tags
        ..answers['${paths.movies}${held.fileName}'] = const MovieTags(
          durationMs: 90000,
        )
        ..hold = true;
      final Future<MovieEntry> reading = reader.read(held);
      await index.put(held.withTitle('First summer'));
      tags.release();
      expect((await reading).title, 'First summer');

      for (int turns = 0; turns < 12; turns++) {
        final String file = 'OSD-Movie-$turns-2023-05-01.mp4';
        final MovieEntry listed = _listed(file);
        tags
          ..answers['${paths.movies}$file'] = const MovieTags(durationMs: 90000)
          ..hold = true;

        final Future<MovieEntry> read = reader.read(listed);
        await pumpEventQueue(times: 1);
        tags.release();
        for (int turn = 0; turn < turns; turn++) {
          await Future<void>.microtask(() {});
        }
        await index.put(listed.withTitle('First summer'));
        await read;

        expect(
          (await index.entries())[file]?.title,
          'First summer',
          reason: 'the rename after $turns turns',
        );
      }
    },
  );
}

/// A movie index whose saves are all refused.
class _RefusingIndex extends MovieIndex {
  _RefusingIndex({required super.paths, required MemoryLogSink sink})
    : super(
        logger: memoryLogger(sink),
        clock: FakeClock(DateTime(2026, 9, 30)),
      );

  @override
  Future<void> put(MovieEntry movie) async =>
      throw const StorageException('Could not save the movie index');

  @override
  Future<MovieEntry> putIfAbsent(MovieEntry movie) async =>
      throw const StorageException('Could not save the movie index');
}
