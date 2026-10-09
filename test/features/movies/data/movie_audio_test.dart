// Music off/on for a movie made with music: the file's description
// is read, its music part rewritten, the audio tracks swapped by the engine
// and the new file put in the movie's place; the index follows.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/movies/data/movie_audio.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../support/fake_movie_repository.dart';

MovieEntry _movie({required bool? musicOn}) => MovieEntry(
  fileName: 'OSD-Movie-3-2026-09-28.mp4',
  title: 'September 2026',
  profile: ProfileKey.defaultProfile,
  clipCount: 2,
  from: LocalDay(2026, 9, 1),
  to: LocalDay(2026, 9, 2),
  createdAt: DateTime(2026, 9, 28, 10),
  durationMs: 3000,
  musicOn: musicOn,
);

ClipProbe _probe(String description) => ClipProbe(
  durationMs: 3000,
  hasAudio: true,
  hasSubtitleStream: false,
  artist: null,
  album: null,
  comment: 'profile=',
  locationTag: null,
  title: 'September 2026',
  description: description,
  width: 1920,
  height: 1080,
  codec: 'h264',
  fps: 30,
);

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late FakeMediaEngine engine;
  late FakeMovieRepository movies;
  late MovieAudio audio;
  late File file;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    engine = FakeMediaEngine(scratchDir: paths.scratchDir);
    movies = FakeMovieRepository(movies: <MovieEntry>[_movie(musicOn: true)]);
    audio = MovieAudio(
      engine: engine,
      publisher: MediaPublisher(
        gateway: FakeMediaStoreGateway.onDisk(paths),
        paths: paths,
        logger: memoryLogger(sink),
        clock: FakeClock(DateTime(2026, 9, 28, 10)),
      ),
      movies: movies,
      paths: paths,
      logger: memoryLogger(sink),
    );
    file = File('${paths.movies}OSD-Movie-3-2026-09-28.mp4');
    await file.create(recursive: true);
    await file.writeAsBytes(<int>[1, 2, 3]);
  });

  test('turns the music off: the description read from the file gets '
      'music=off, the engine swaps the tracks, the new file takes the '
      'movie\'s place, and the index records it; on again the same way; a '
      'movie without music is left alone', () async {
    engine.probes[file.path] = _probe(
      'clips=2;from=2026-09-01;to=2026-09-02;music=on;transition=fade',
    );

    final MovieEntry off = await audio.toggle(_movie(musicOn: true));

    expect(off, _movie(musicOn: false));
    expect(engine.swapRequests, <({String moviePath, String description})>[
      (
        moviePath: file.path,
        description:
            'clips=2;from=2026-09-01;to=2026-09-02;music=off;transition=fade',
      ),
    ]);
    // The swapped file (the fake engine's bytes) is the movie now.
    expect(await file.readAsBytes(), isNot(<int>[1, 2, 3]));
    expect(movies.updated, <MovieEntry>[off]);
    expect(movies.movies.single.musicOn, isFalse);
    expect(sink.lines, contains(contains('[MOVIE AUDIO] Turned the music')));

    engine.probes[file.path] = _probe(
      'clips=2;from=2026-09-01;to=2026-09-02;music=off;transition=fade',
    );
    expect(await audio.toggle(off), _movie(musicOn: true));
    expect(engine.swapRequests.last.description, contains('music=on'));

    expect(await audio.toggle(_movie(musicOn: null)), _movie(musicOn: null));
    expect(engine.swapRequests, hasLength(2));

    // The file says which track plays, never the index entry: a stale
    // entry (the index write failed last time) still swaps the right way.
    engine.probes[file.path] = _probe(
      'clips=2;from=2026-09-01;to=2026-09-02;music=on;transition=fade',
    );
    expect(await audio.toggle(_movie(musicOn: false)), _movie(musicOn: false));
    expect(engine.swapRequests.last.description, contains('music=off'));
  });

  test('a swap the engine cannot make throws, and nothing changes', () async {
    engine.probes[file.path] = _probe(
      'clips=2;from=2026-09-01;to=2026-09-02;music=on',
    );
    engine.swapError = const VideoProcessingException(
      'swap',
      returnCode: 1,
      logTail: '',
    );

    await expectLater(
      audio.toggle(_movie(musicOn: true)),
      throwsA(isA<VideoProcessingException>()),
    );
    expect(await file.readAsBytes(), <int>[1, 2, 3]);
    expect(movies.updated, isEmpty);
  });
}
