import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_queue.dart';
import 'package:one_second_diary/features/movies/data/movie_posters.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/eventually.dart';

MovieEntry _movie(String fileName, {VideoOrientation? orientation}) =>
    MovieEntry(
      fileName: fileName,
      title: fileName,
      profile: null,
      clipCount: null,
      from: null,
      to: null,
      createdAt: DateTime(2025, 12, 31),
      durationMs: null,
      orientation: orientation,
    );

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late FakeThumbnailGateway gateway;
  late ThumbnailQueue queue;
  late MoviePosters posters;

  setUp(() async {
    queue = ThumbnailQueue(maxRunning: 2);
    paths = await createTestPaths();
    sink = MemoryLogSink();
    gateway = FakeThumbnailGateway();
    posters = MoviePosters(
      gateway: gateway,
      queue: queue,
      paths: paths,
      logger: memoryLogger(sink),
    );
  });

  Future<MovieEntry> seed(
    String fileName, {
    VideoOrientation? orientation,
  }) async {
    await seedFile(paths, 'Movies/$fileName');
    return _movie(fileName, orientation: orientation);
  }

  test("a movie's poster is its first frame, made once in the app's "
      'thumbnail cache at poster size in the bounds of its canvas (never full '
      'resolution, F §3.2), served from disk in a later session and made '
      'again for a replaced file; an unreadable or missing movie has none '
      '(logged)', () async {
    final MovieEntry movie = await seed('OSD-Movie-1-2025-12-31.mp4');
    final MovieEntry portrait = await seed(
      'Kids/OSD-Movie-2-2025-12-31.mp4',
      orientation: VideoOrientation.portrait,
    );
    expect(
      posters.cachedFile(movie.fileName, orientation: movie.orientation),
      isNull,
    );

    final String? poster = await posters
        .request(movie.fileName, orientation: movie.orientation)
        .file;
    await posters
        .request(portrait.fileName, orientation: portrait.orientation)
        .file;

    expect(poster, startsWith('${paths.thumbsDir}/movies/'));
    expect(await File(poster!).exists(), isTrue);
    expect(
      <(String, int?, int?, int?)>[
        for (final ThumbnailRequest request in gateway.requests)
          (
            request.videoPath,
            request.maxWidth,
            request.maxHeight,
            request.timeMs,
          ),
      ],
      <(String, int?, int?, int?)>[
        ('${paths.movies}${movie.fileName}', 720, 405, 0),
        // Android 8.0 scales to exactly the bounds given.
        ('${paths.movies}${portrait.fileName}', 405, 720, 0),
      ],
    );
    expect(
      posters.cachedFile(movie.fileName, orientation: movie.orientation),
      poster,
    );

    // From here on a new frame cannot be made: a later session serves the
    // poster from disk.
    gateway.failingVideos.add('${paths.movies}${movie.fileName}');
    final MoviePosters later = MoviePosters(
      gateway: gateway,
      queue: queue,
      paths: paths,
      logger: memoryLogger(sink),
    );
    expect(
      await later.request(movie.fileName, orientation: movie.orientation).file,
      poster,
    );

    gateway.failingVideos.clear();
    await File(
      '${paths.movies}${movie.fileName}',
    ).writeAsBytes(<int>[1, 2, 3, 4, 5, 6, 7]);
    final String? replaced = await posters
        .request(movie.fileName, orientation: movie.orientation)
        .file;
    expect(replaced, isNot(poster));
    expect(await File(replaced!).exists(), isTrue);

    final MovieEntry broken = await seed('OSD-Movie-3-2025-12-31.mp4');
    gateway.failingVideos.add('${paths.movies}${broken.fileName}');
    expect(await posters.request(broken.fileName).file, isNull);
    expect(await posters.request('OSD-Movie-9-2025-12-31.mp4').file, isNull);
    expect(
      sink.lines.where((String line) => line.contains('[WARNING]')),
      hasLength(2),
    );
  });

  test("posters share the one queue with the clips' thumbnails: a clip "
      'thumbnail being made takes a slot from them', () async {
    final List<MovieEntry> movies = <MovieEntry>[
      for (int n = 1; n <= 2; n++) await seed('OSD-Movie-$n-2025-12-31.mp4'),
    ];
    gateway.holdRequests = true;
    final Completer<String?> clipThumbnail = Completer<String?>();
    queue.request('a clip thumbnail', () => clipThumbnail.future);

    for (final MovieEntry movie in movies) {
      posters.request(movie.fileName, orientation: movie.orientation);
    }
    await eventually(() => gateway.inFlight >= 1);
    await pumpEventQueue(times: 50); // time for a second, were it shared out
    expect(gateway.inFlight, 1);

    clipThumbnail.complete(null);
    await eventually(() => gateway.inFlight == 2);
    gateway.completePending();
  });
}
