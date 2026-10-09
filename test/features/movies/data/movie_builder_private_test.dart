// Private clips and the movie builder: a range leaves them out unless
// included, the movie's tags say how many it holds, and a clip the engine
// found private is left out and told to the library.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/movie_clip.dart';
import 'package:one_second_diary/core/media/types/movie_render_request.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/movies/data/movie_builder.dart';
import 'package:one_second_diary/features/movies/data/movie_index.dart';
import 'package:one_second_diary/features/movies/data/movie_repository.dart';
import 'package:one_second_diary/features/movies/domain/movie_build_event.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late FakeMediaEngine engine;
  late ClipRepository clips;
  late MovieBuilder builder;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    final FakeClock clock = FakeClock(DateTime(2026, 9, 29, 10));
    engine = FakeMediaEngine(scratchDir: paths.scratchDir);
    clips = ClipRepository(
      scanner: ClipScanner(paths: paths, logger: memoryLogger(sink)),
      paths: paths,
      logger: memoryLogger(sink),
    );
    addTearDown(clips.dispose);
    final MediaPublisher publisher = MediaPublisher(
      gateway: FakeMediaStoreGateway.onDisk(paths),
      paths: paths,
      logger: memoryLogger(sink),
      clock: clock,
    );
    builder = MovieBuilder(
      engine: engine,
      clips: clips,
      metadata: ClipMetadataCache(paths: paths, logger: memoryLogger(sink)),
      movies: MovieRepository(
        index: MovieIndex(
          paths: paths,
          logger: memoryLogger(sink),
          clock: clock,
        ),
        publisher: publisher,
        prefs: await openLegacyPrefs(legacyPrefs()),
        paths: paths,
        logger: memoryLogger(sink),
      ),
      publisher: publisher,
      paths: paths,
      clock: clock,
      logger: memoryLogger(sink),
    );
    for (final int day in <int>[3, 4, 5, 6]) {
      await seedClip(paths, _default, LocalDay(2026, 9, day));
    }
    await clips.loadAll(active: _default, profiles: <ProfileKey>[]);
    clips.privacyKnown('2026-09-05.mp4', private: true);
  });

  Future<MovieEntry> september({required bool includePrivate}) async {
    final List<MovieBuildEvent> events = await builder
        .build(
          source: const MovieSource.month(year: 2026, month: 9),
          profile: _default,
          format: const ClipFormat.legacy(VideoOrientation.landscape),
          title: 'September 2026',
          includePrivate: includePrivate,
        )
        .toList();
    return (events.last as MovieBuilt).movie;
  }

  List<String> joined(MovieRenderRequest request) => <String>[
    for (final MovieClip clip in request.clips)
      paths.relativeToVideos(clip.path),
  ];

  test('a range leaves the private clip out and asks the engine to leave '
      'out any it finds private; included, the clip is joined and the '
      "movie's tags and entry count it", () async {
    final MovieEntry without = await september(includePrivate: false);

    final MovieRenderRequest excluding = engine.movieRequests.single;
    expect(joined(excluding), <String>[
      '2026-09-03.mp4',
      '2026-09-04.mp4',
      '2026-09-06.mp4',
    ]);
    expect(excluding.excludePrivate, isTrue);
    expect(excluding.description, 'clips=3;from=2026-09-03;to=2026-09-06');
    expect(without.clipCount, 3);
    expect(without.privateClipCount, 0);

    final MovieEntry with_ = await september(includePrivate: true);

    final MovieRenderRequest including = engine.movieRequests.last;
    expect(joined(including), hasLength(4));
    expect(including.excludePrivate, isFalse);
    expect(
      including.description,
      'clips=4;from=2026-09-03;to=2026-09-06;private=1',
    );
    expect(with_.privateClipCount, 1);
  });

  test(
    'a clip the engine found private is left out of the movie, reported '
    'as such (not as unreadable) and known to the library from then on',
    () async {
      engine.movieLeftOutPrivate = const <int>[2]; // 2026-09-06.mp4

      final List<MovieBuildEvent> events = await builder
          .build(
            source: const MovieSource.month(year: 2026, month: 9),
            profile: _default,
            format: const ClipFormat.legacy(VideoOrientation.landscape),
            title: 'September 2026',
          )
          .toList();
      final MovieBuilt built = events.last as MovieBuilt;
      final MovieEntry movie = built.movie;

      expect(built.skipped, isEmpty);
      expect(built.leftOutPrivate, <ClipRef>[
        ClipRef(profile: _default, relPath: '2026-09-06.mp4'),
      ]);
      expect(movie.clipCount, 2);
      expect(movie.to, LocalDay(2026, 9, 4));
      expect(
        clips
            .snapshotOf(_default)!
            .isPrivate(ClipRef(profile: _default, relPath: '2026-09-06.mp4')),
        isTrue,
      );
    },
  );
}
