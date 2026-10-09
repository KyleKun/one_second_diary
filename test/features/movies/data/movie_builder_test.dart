import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/commands/concat_command.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/policy/concat_list.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/core/media/types/movie_clip.dart';
import 'package:one_second_diary/core/media/types/movie_music.dart';
import 'package:one_second_diary/core/media/types/movie_render_event.dart';
import 'package:one_second_diary/core/media/types/movie_render_request.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/movies/data/movie_builder.dart';
import 'package:one_second_diary/features/movies/data/movie_index.dart';
import 'package:one_second_diary/features/movies/data/movie_repository.dart';
import 'package:one_second_diary/features/movies/domain/movie_build_event.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../../../support/track_1a/media_engine_harness.dart';
import '../../../support/track_1a/scripted_ffmpeg_gateway.dart';
import '../../../support/track_1b/eventually.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

/// Clips in the perf guard's movie (about 13 years of daily clips).
const int _bigMovie = 5000;

/// Generous for a debug-mode `flutter test` on a slow CI runner: planning
/// 5 000 clips takes about 7 ms on a laptop, and a per-clip listing or
/// probe would take seconds.
const Duration _planBudget = Duration(milliseconds: 250);

/// The perf guard's movies: the best planning time counts, after a first
/// one that warms the JIT up (a GC pause spoils one, not the budget).
const int _planRounds = 3;

/// Today in these tests: the day the movies are made.
final DateTime _now = DateTime(2026, 9, 29, 10);

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late FakeClock clock;
  late FakeMediaEngine engine;
  late FakeMediaStoreGateway gallery;
  late ClipRepository clips;
  late ClipMetadataCache metadata;
  late PrefsStore prefs;
  late MovieRepository movies;
  late MediaPublisher publisher;
  late MovieBuilder builder;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    clock = FakeClock(_now);
    engine = FakeMediaEngine(scratchDir: paths.scratchDir);
    gallery = FakeMediaStoreGateway.onDisk(paths);
    clips = ClipRepository(
      scanner: ClipScanner(paths: paths, logger: memoryLogger(sink)),
      paths: paths,
      logger: memoryLogger(sink),
    );
    addTearDown(clips.dispose);
    metadata = ClipMetadataCache(paths: paths, logger: memoryLogger(sink));
    prefs = await openLegacyPrefs(legacyPrefs());
    publisher = MediaPublisher(
      gateway: gallery,
      paths: paths,
      logger: memoryLogger(sink),
      clock: clock,
    );
    movies = MovieRepository(
      index: MovieIndex(paths: paths, logger: memoryLogger(sink), clock: clock),
      publisher: publisher,
      prefs: prefs,
      paths: paths,
      logger: memoryLogger(sink),
    );
    builder = MovieBuilder(
      engine: engine,
      clips: clips,
      metadata: metadata,
      movies: movies,
      publisher: publisher,
      paths: paths,
      clock: clock,
      logger: memoryLogger(sink),
    );
  });

  /// Caches [meta] for the clip at [relPath] with the stamp the scan saw.
  void cacheMeta(
    String relPath,
    ClipMeta meta, {
    ProfileKey profile = _default,
  }) => metadata.put(
    relPath: relPath,
    stamp: clips
        .snapshotOf(profile)!
        .stampOf(ClipRef(profile: profile, relPath: relPath))!,
    meta: meta,
  );

  /// A builder like the one in setUp, over [engine].
  MovieBuilder rebuild({required MediaEngine engine}) => MovieBuilder(
    engine: engine,
    clips: clips,
    metadata: metadata,
    movies: movies,
    publisher: publisher,
    paths: paths,
    clock: clock,
    logger: memoryLogger(sink),
  );

  /// What is left in the scratch folder (the engine's and the builder's).
  Future<List<String>> scratchEntries() async {
    final Directory scratch = Directory(paths.scratchDir);
    if (!await scratch.exists()) return const <String>[];
    return <String>[
      await for (final FileSystemEntity entity in scratch.list(recursive: true))
        entity.path,
    ];
  }

  /// Makes the Default profile's September 2026 movie and returns its
  /// events.
  Future<List<MovieBuildEvent>> buildSeptember() => builder
      .build(
        source: const MovieSource.month(year: 2026, month: 9),
        profile: _default,
        format: const ClipFormat.legacy(VideoOrientation.landscape),
        title: 'September 2026',
      )
      .toList();

  /// Scans the profiles, as the app does after the first frame.
  Future<void> scan() => clips.loadAll(
    active: _default,
    profiles: const <ProfileKey>[ProfileKey('Kids')],
  );

  test('Z-01 fixed: a month movie has every clip of each day of the month, by '
      'day then ordinal (decision D1), each at its real path (v1.7 wrote '
      '<root>/<day>.mp4, which may not exist) and a duplicate date in a '
      'sub-folder once; each clip carries its cached facts as they are, a '
      'null for the engine to probe, its chapter title (D25), and the '
      'builder never probes', () async {
    await seedClip(paths, _default, LocalDay(2026, 9, 1), ordinal: 2);
    await seedClip(paths, _default, LocalDay(2026, 9, 1));
    await seedClip(paths, _default, LocalDay(2026, 9, 1), subFolder: 'Old');
    await seedClip(paths, _default, LocalDay(2026, 9, 2), subFolder: 'Backup');
    await seedClip(paths, _default, LocalDay(2026, 8, 31)); // another month
    await scan();
    // Backfilled or written at save time: every fact known.
    cacheMeta(
      '2026-09-01.mp4',
      const ClipMeta(
        durationMs: 2500,
        hasAudio: true,
        hasSubtitleStream: false,
        isOsdV15: true,
        width: 1920,
        height: 1080,
        codec: 'h264',
      ),
    );
    // An older install's clip the backfill probed: no artist tag, no audio.
    cacheMeta(
      'Backup/2026-09-02.mp4',
      const ClipMeta(
        durationMs: 1000,
        hasAudio: false,
        hasSubtitleStream: false,
        isOsdV15: false,
        width: 1280,
        height: 720,
        codec: 'hevc',
      ),
    );
    // 2026-09-01-2 is not backfilled yet: nothing known.

    await buildSeptember();

    expect(engine.movieRequests.single.clips, <MovieClip>[
      MovieClip(
        path: '${paths.videos}2026-09-01.mp4',
        durationMs: 2500,
        isOsdV15: true,
        hasAudio: true,
        hasSubtitleStream: false,
        width: 1920,
        height: 1080,
        codec: 'h264',
        chapterTitle: 'September 1, 2026 (1)',
      ),
      MovieClip(
        path: '${paths.videos}2026-09-01-2.mp4',
        durationMs: null,
        isOsdV15: null,
        hasAudio: null,
        hasSubtitleStream: null,
        width: null,
        height: null,
        codec: null,
        chapterTitle: 'September 1, 2026 (2)',
      ),
      MovieClip(
        path: '${paths.videos}Backup/2026-09-02.mp4',
        durationMs: 1000,
        isOsdV15: false,
        hasAudio: false,
        hasSubtitleStream: false,
        width: 1280,
        height: 720,
        codec: 'hevc',
        chapterTitle: 'September 2, 2026',
      ),
    ]);
    expect(engine.probedPaths, isEmpty);
  });

  test('a finished movie: rendered in scratch under its file name, published '
      'into Movies/ as the next free OSD-Movie-<n>-<today>.mp4 (never over an '
      'existing one), tagged profile= and described by its clips and days '
      '(decision O9), registered with its facts exactly as My movies lists '
      'it, movieCount written for v1.7; the stream says what M6 shows, in '
      'order', () async {
    await seedClip(paths, _default, LocalDay(2026, 9, 3));
    await seedClip(paths, _default, LocalDay(2026, 9, 5));
    await seedClip(paths, _default, LocalDay(2026, 9, 5), ordinal: 2);
    await seedFile(paths, 'Movies/OSD-Movie-4-2026-09-29.mp4');
    await scan();
    cacheMeta('2026-09-03.mp4', const ClipMeta(durationMs: 2500));
    cacheMeta('2026-09-05.mp4', const ClipMeta(durationMs: 1500));
    cacheMeta('2026-09-05-2.mp4', const ClipMeta(durationMs: 1000));
    // The index keeps milliseconds.
    clock.setNow(DateTime(2026, 9, 29, 10, 15, 30, 250, 999));
    final MovieEntry expected = MovieEntry(
      fileName: 'OSD-Movie-5-2026-09-29.mp4',
      title: 'September 2026',
      profile: _default,
      clipCount: 3,
      from: LocalDay(2026, 9, 3),
      to: LocalDay(2026, 9, 5),
      createdAt: DateTime(2026, 9, 29, 10, 15, 30, 250),
      durationMs: 5000,
      orientation: VideoOrientation.landscape,
      chapters: const <MovieChapter>[
        MovieChapter(startMs: 0, endMs: 2500, title: 'September 3, 2026'),
        MovieChapter(
          startMs: 2500,
          endMs: 4000,
          title: 'September 5, 2026 (1)',
        ),
        MovieChapter(
          startMs: 4000,
          endMs: 5000,
          title: 'September 5, 2026 (2)',
        ),
      ],
    );

    final List<MovieBuildEvent> events = await buildSeptember();

    expect(events, <MovieBuildEvent>[
      MovieBuildStarted(<ClipRef>[
        ClipRef(profile: _default, relPath: '2026-09-03.mp4'),
        ClipRef(profile: _default, relPath: '2026-09-05.mp4'),
        ClipRef(profile: _default, relPath: '2026-09-05-2.mp4'),
      ]),
      const MovieBuildProgress(MoviePreparing(index: 0, total: 3)),
      const MovieBuildProgress(MoviePreparing(index: 1, total: 3)),
      const MovieBuildProgress(MoviePreparing(index: 2, total: 3)),
      const MovieBuildProgress(
        MovieConcatenating(fraction: 1, currentIndex: 2),
      ),
      // The movie is being saved into the gallery.
      const MovieBuildFinishing(),
      MovieBuilt(expected),
    ]);
    final MovieRenderRequest request = engine.movieRequests.single;
    expect(request.outputPath, startsWith('${paths.scratchDir}/'));
    expect(request.outputPath, endsWith('/OSD-Movie-5-2026-09-29.mp4'));
    expect(request.comment, 'profile=');
    expect(request.description, 'clips=3;from=2026-09-03;to=2026-09-05');
    expect(gallery.calls, <MediaStoreCall>[
      PublishCall(
        tempFilePath: request.outputPath,
        album: 'OneSecondDiary/Movies',
      ),
    ]);
    expect(
      await File('${paths.movies}OSD-Movie-5-2026-09-29.mp4').readAsBytes(),
      fakeVideoBytes,
    );
    expect(await File(request.outputPath).exists(), isFalse);
    final MovieRepository restarted = MovieRepository(
      index: MovieIndex(paths: paths, logger: memoryLogger(sink), clock: clock),
      publisher: publisher,
      prefs: prefs,
      paths: paths,
      logger: memoryLogger(sink),
    );
    expect(await restarted.list(), contains(expected));
    expect(prefs.read(PrefKeys.movieCount), 6);
  });

  // A clip that cannot be read is left out, not the whole movie.
  test('a movie made without a clip the engine could not read is registered '
      'with the clips joined and their days, and says which was left '
      'out', () async {
    await seedClip(paths, _default, LocalDay(2026, 9, 3));
    await seedClip(paths, _default, LocalDay(2026, 9, 5));
    await seedClip(paths, _default, LocalDay(2026, 9, 7));
    await scan();
    engine.movieSkipped = const <int>[0];

    final List<MovieBuildEvent> events = await buildSeptember();

    final MovieBuilt built = events.last as MovieBuilt;
    expect(built.skipped, <ClipRef>[
      ClipRef(profile: _default, relPath: '2026-09-03.mp4'),
    ]);
    expect(built.movie.clipCount, 2);
    expect(
      (built.movie.from, built.movie.to),
      (LocalDay(2026, 9, 5), LocalDay(2026, 9, 7)),
    );
  });

  // The chapters the engine wrote are what the index keeps,
  // titled from the cache's place and subtitle; a clip left out is none.
  test('the chapters of a movie, titled with each clip\'s day, place and '
      'subtitle from the cached facts, land in the MovieEntry and in the '
      'movie index; a clip the engine left out is no chapter', () async {
    await seedClip(paths, _default, LocalDay(2026, 9, 3));
    await seedClip(paths, _default, LocalDay(2026, 9, 5));
    await seedClip(paths, _default, LocalDay(2026, 9, 7));
    await scan();
    cacheMeta(
      '2026-09-03.mp4',
      const ClipMeta(durationMs: 2500, locationText: 'Berlin'),
    );
    cacheMeta(
      '2026-09-05.mp4',
      const ClipMeta(
        durationMs: 1500,
        locationText: 'Berlin',
        subtitleText: 'eating bananas\nwith friends',
      ),
    );
    cacheMeta('2026-09-07.mp4', const ClipMeta(durationMs: 1000));
    engine.movieSkipped = const <int>[0];

    final MovieBuilt built = (await buildSeptember()).last as MovieBuilt;

    expect(
      engine.movieRequests.single.clips
          .map((MovieClip clip) => clip.chapterTitle)
          .toList(),
      <String>[
        'September 3, 2026 · Berlin',
        'September 5, 2026 · Berlin · eating bananas',
        'September 7, 2026',
      ],
    );
    const List<MovieChapter> chapters = <MovieChapter>[
      MovieChapter(
        startMs: 0,
        endMs: 1500,
        title: 'September 5, 2026 · Berlin · eating bananas',
      ),
      MovieChapter(startMs: 1500, endMs: 2500, title: 'September 7, 2026'),
    ];
    expect(built.movie.chapters, chapters);
    expect(built.movie.chapterAt(1600)?.title, 'September 7, 2026');
    final MovieRepository restarted = MovieRepository(
      index: MovieIndex(paths: paths, logger: memoryLogger(sink), clock: clock),
      publisher: publisher,
      prefs: prefs,
      paths: paths,
      logger: memoryLogger(sink),
    );
    expect(
      (await restarted.list())
          .singleWhere(
            (MovieEntry movie) => movie.fileName == built.movie.fileName,
          )
          .chapters,
      chapters,
    );
  });

  test('a movie of a profile that is not the active one is made from THAT '
      "profile's clips, scanned first when they were not yet, and tagged "
      'with its immutable key, never its display name (decision D3, '
      'CONTRACTS §4)', () async {
    const ProfileKey travel = ProfileKey('Travel');
    await seedClip(paths, _default, LocalDay(2026, 9, 1));
    await seedClip(paths, _default, LocalDay(2026, 9, 2));
    await seedClip(paths, travel, LocalDay(2026, 9, 1));
    await seedClip(paths, travel, LocalDay(2026, 9, 4));
    await scan(); // Default and Kids: Travel is not scanned yet.

    final List<MovieBuildEvent> events = await builder
        .build(
          source: const MovieSource.month(year: 2026, month: 9),
          profile: travel,
          format: const ClipFormat.legacy(VideoOrientation.portrait),
          title: 'September 2026',
        )
        .toList();

    final MovieRenderRequest request = engine.movieRequests.single;
    expect(request.clips.map((MovieClip clip) => clip.path), <String>[
      '${paths.videos}Profiles/Travel/2026-09-01.mp4',
      '${paths.videos}Profiles/Travel/2026-09-04.mp4',
    ]);
    expect(request.orientation, VideoOrientation.portrait);
    expect(request.title, 'September 2026');
    expect(request.comment, 'profile=Travel');
    final MovieEntry movie = (events.last as MovieBuilt).movie;
    expect(
      (movie.profile, movie.orientation),
      (travel, VideoOrientation.portrait),
    );
  });

  // The movie is made in the profile's format, which the
  // caller reads from `ProfilesRepository.formatOf`, never the legacy one.
  // Asked for 1080p30 H.264 instead (the leftover this guards
  // against), the engine would normalise every 4K clip into a 1080p copy
  // (three more ffmpeg runs) and join them at `-r 30`.
  test(
    'a movie of an Ultra profile (2160p60 HEVC stereo) whose cached '
    'facts match it is one concat of the clips as they are at -r 60: no '
    'probe, no normalised copy; the movie records the format\'s canvas',
    () async {
      const ProfileKey ultraKey = ProfileKey('Ultra');
      final ClipFormat ultra = ClipFormatPreset.ultra.format(
        VideoOrientation.landscape,
      );
      const ClipMeta ultraMeta = ClipMeta(
        durationMs: 1500,
        hasAudio: true,
        hasSubtitleStream: false,
        isOsdV15: false,
        width: 3840,
        height: 2160,
        codec: 'hevc',
        fps: 60,
        channels: 2,
        pixelFormat: 'yuv420p',
      );
      final File day1 = await seedClip(paths, ultraKey, LocalDay(2026, 9, 1));
      final File day2 = await seedClip(paths, ultraKey, LocalDay(2026, 9, 2));
      await clips.rescan(ultraKey);
      cacheMeta('Profiles/Ultra/2026-09-01.mp4', ultraMeta, profile: ultraKey);
      cacheMeta('Profiles/Ultra/2026-09-02.mp4', ultraMeta, profile: ultraKey);
      // The real engine over a scripted ffmpeg: the plan and the argv are
      // the engine's, not a fake's.
      final ScriptedFfmpegGateway ffmpeg = ScriptedFfmpegGateway(clock: clock);
      final MovieBuilder real = rebuild(
        engine: engineOver(ffmpeg: ffmpeg, paths: paths, clock: clock),
      );

      final List<MovieBuildEvent> events = await real
          .build(
            source: const MovieSource.month(year: 2026, month: 9),
            profile: ultraKey,
            format: ultra,
            title: 'September 2026',
          )
          .toList();

      expect(ffmpeg.probed, isEmpty, reason: 'every fact came from the cache');
      final List<String> argv = ffmpeg.executed.single;
      final String listPath = argv[argv.indexOf('-i') + 1];
      final String chaptersPath = argv[argv.lastIndexOf('-i') + 1];
      final String outputPath = argv[argv.length - 2];
      expect(outputPath, startsWith('${paths.scratchDir}/movie-'));
      expect(outputPath, endsWith('/OSD-Movie-1-2026-09-29.mp4'));
      expect(
        argv,
        ConcatCommand.build(
          listPath: listPath,
          outputPath: outputPath,
          fps: FrameRate.f60,
          title: 'September 2026',
          comment: 'profile=Ultra',
          description: 'clips=2;from=2026-09-01;to=2026-09-02',
          chaptersPath: chaptersPath,
        ),
      );
      expect(
        ffmpeg.textInputs[listPath],
        ConcatList.content(<String>[day1.path, day2.path]),
        reason: 'the clips themselves, no normalised copy',
      );
      final MovieEntry movie = (events.last as MovieBuilt).movie;
      expect(
        (movie.profile, movie.orientation, movie.durationMs),
        (ultraKey, VideoOrientation.landscape, 3000),
      );
    },
  );

  test("fewer than two clips (v1.7's movieInsufficientVideos) ends the "
      'stream with an ArgumentError before any work, and v1.7\'s warning '
      'names the clips there were', () async {
    await seedClip(paths, _default, LocalDay(2026, 9, 1));
    await seedClip(paths, _default, LocalDay(2026, 8, 31));
    await scan();

    await expectLater(buildSeptember(), throwsArgumentError);

    expect(engine.movieRequests, isEmpty);
    expect(gallery.calls, isEmpty);
    expect(await Directory(paths.scratchDir).exists(), isFalse);
    expect(
      sink.lines,
      contains(
        allOf(
          contains('[WARNING]'),
          contains(
            '[CREATE MOVIE] Insufficient videos to create movie. Videos: '
            '[2026-09-01.mp4]',
          ),
        ),
      ),
    );
  });

  test('a failed render leaves nothing: the builder deletes its partial '
      'output and scratch folder, publishes and registers nothing, and the '
      "stream ends with the engine's error (Z MB-08); a movie the gallery "
      'refuses ends it with a MediaStoreException, registering nothing '
      'either', () async {
    await seedClip(paths, _default, LocalDay(2026, 9, 1));
    await seedClip(paths, _default, LocalDay(2026, 9, 2));
    await scan();
    gallery.publishResults.add(false);
    await expectLater(buildSeptember(), throwsA(isA<MediaStoreException>()));
    expect(await movies.list(), isEmpty);
    expect(prefs.read(PrefKeys.movieCount), 1);
    expect(await scratchEntries(), isEmpty);

    final _PartialMovieEngine failing = _PartialMovieEngine(
      scratchDir: paths.scratchDir,
      error: const VideoProcessingException(
        'concat failed',
        returnCode: 1,
        logTail: 'No space left on device',
      ),
    );
    builder = rebuild(engine: failing);

    await expectLater(
      buildSeptember(),
      throwsA(isA<VideoProcessingException>()),
    );

    expect(failing.partialOutputs, hasLength(1));
    expect(await File(failing.partialOutputs.single).exists(), isFalse);
    expect(await scratchEntries(), isEmpty);
    expect(await movies.list(), isEmpty);
    expect(prefs.read(PrefKeys.movieCount), 1);
    expect(
      sink.lines,
      contains(
        allOf(<Matcher>[
          contains('[ERROR]'),
          contains('[CREATE MOVIE]'),
          contains('Error creating movie -> Movies/OSD-Movie-1-2026-09-29.mp4'),
          contains('concat failed'),
        ]),
      ),
    );
  });

  test(
    "cancelling the token stops the engine's session and ends the stream "
    'with a CancelledException; cancelling the subscription (a Bloc '
    'closing mid-movie) does the same; a cancel that lands as the engine '
    'completes still wins; nothing is published or left either way',
    () async {
      await seedClip(paths, _default, LocalDay(2026, 9, 1));
      await seedClip(paths, _default, LocalDay(2026, 9, 2));
      await scan();
      engine.holdMovie = true;
      final CancelToken token = CancelToken();
      final Future<List<MovieBuildEvent>> events = builder
          .build(
            source: const MovieSource.month(year: 2026, month: 9),
            profile: _default,
            format: const ClipFormat.legacy(VideoOrientation.landscape),
            title: 'September 2026',
            cancelToken: token,
          )
          .toList();
      await eventually(() => engine.movieRequests.isNotEmpty);

      token.cancel();

      await expectLater(events, throwsA(isA<CancelledException>()));
      expect(await scratchEntries(), isEmpty);
      expect(
        sink.lines,
        contains(
          allOf(
            contains('[INFO]'),
            contains(
              'Execution was cancelled: Movies/OSD-Movie-1-2026-09-29.mp4',
            ),
          ),
        ),
      );

      final StreamSubscription<MovieBuildEvent> subscription = builder
          .build(
            source: const MovieSource.month(year: 2026, month: 9),
            profile: _default,
            format: const ClipFormat.legacy(VideoOrientation.landscape),
            title: 'September 2026',
          )
          .listen(null);
      await eventually(() => engine.movieRequests.length == 2);

      await subscription.cancel();

      expect(await scratchEntries(), isEmpty);
      engine.releaseMovie(); // the session is over: nothing may come of it
      await pumpEventQueue();

      builder = rebuild(engine: _CancelledAtTheEndEngine(paths.scratchDir));
      await expectLater(
        builder
            .build(
              source: const MovieSource.month(year: 2026, month: 9),
              profile: _default,
              format: const ClipFormat.legacy(VideoOrientation.landscape),
              title: 'September 2026',
              cancelToken: CancelToken(),
            )
            .toList(),
        throwsA(isA<CancelledException>()),
      );

      expect(gallery.calls, isEmpty);
      expect(await movies.list(), isEmpty);
      expect(await scratchEntries(), isEmpty);
    },
  );

  test('a file that took the movie\'s name while it was being made is never '
      'overwritten: the movie takes the next free name', () async {
    await seedClip(paths, _default, LocalDay(2026, 9, 1));
    await seedClip(paths, _default, LocalDay(2026, 9, 2));
    await scan();
    engine.holdMovie = true;
    final Future<List<MovieBuildEvent>> events = buildSeptember();
    await eventually(() => engine.movieRequests.isNotEmpty);
    expect(
      engine.movieRequests.single.outputPath,
      endsWith('/OSD-Movie-1-2026-09-29.mp4'),
    );
    // Copied in meanwhile (a Files-app copy, another install's movie).
    await seedFile(
      paths,
      'Movies/OSD-Movie-1-2026-09-29.mp4',
      bytes: const <int>[4, 2],
    );

    engine.releaseMovie();
    final MovieBuilt built = (await events).last as MovieBuilt;

    expect(built.movie.fileName, 'OSD-Movie-2-2026-09-29.mp4');
    expect(
      await File('${paths.movies}OSD-Movie-1-2026-09-29.mp4').readAsBytes(),
      const <int>[4, 2],
    );
    expect(
      await File('${paths.movies}OSD-Movie-2-2026-09-29.mp4').readAsBytes(),
      fakeVideoBytes,
    );
  });

  test('a movie index that cannot be saved does not fail a published movie: '
      'it is logged, and the movie lists with the date in its name', () async {
    await seedClip(paths, _default, LocalDay(2026, 9, 1));
    await seedClip(paths, _default, LocalDay(2026, 9, 2));
    await scan();
    await File(paths.supportIndexDir).writeAsString('in the way');

    final List<MovieBuildEvent> events = await buildSeptember();

    expect(events.last, isA<MovieBuilt>());
    expect(
      (await movies.list()).single.title,
      '2026-09-29',
      reason: 'listed as a movie the index does not know',
    );
    expect(
      sink.lines,
      contains(allOf(contains('[ERROR]'), contains('movie index'))),
    );
  });

  test("the log says, in v1.7's [CREATE MOVIE] lines, which movie is made "
      'from which clips (the range of a month or a preset, or the clips '
      'picked by hand), how far it got, and that it was saved', () async {
    await seedClip(paths, _default, LocalDay(2026, 9, 1));
    await seedClip(paths, _default, LocalDay(2026, 9, 2), subFolder: 'trip');
    await scan();
    ClipRef clip(String relPath) =>
        ClipRef(profile: _default, relPath: relPath);

    await buildSeptember();

    final List<String> movieLines = <String>[
      for (final String line in sink.lines)
        if (line.contains('[INFO]') && line.contains('[CREATE MOVIE]'))
          line.substring(line.indexOf('[CREATE MOVIE]') + 15),
    ];
    expect(movieLines, <Matcher>[
      equals(
        'Creating movie in range 2026-09 with the following videos: '
        '[2026-09-01.mp4, trip/2026-09-02.mp4]',
      ),
      equals('Base videos folder: ${paths.videos}'),
      equals('Movie will be saved as: Movies/OSD-Movie-1-2026-09-29.mp4'),
      equals('Progress: 0 / 2'),
      equals('Progress: 1 / 2'),
      equals('Finished checking videos... creating movie...'),
      equals('Movie saved! Movies/OSD-Movie-1-2026-09-29.mp4'),
      startsWith('Deleting temp files... : '),
    ]);

    await builder
        .build(
          source: const MovieSource.preset(MoviePreset.thisMonth),
          profile: _default,
          format: const ClipFormat.legacy(VideoOrientation.landscape),
          title: 'September 2026',
        )
        .drain<void>();
    await builder
        .build(
          source: MovieSource.custom(<ClipRef>{
            clip('trip/2026-09-02.mp4'),
            clip('2026-09-01.mp4'),
          }),
          profile: _default,
          format: const ClipFormat.legacy(VideoOrientation.landscape),
          title: '2 hand-picked clips',
        )
        .drain<void>();
    expect(
      sink.lines,
      containsAll(<Matcher>[
        contains(
          'Creating movie in range thisMonth with the following videos: '
          '[2026-09-01.mp4, trip/2026-09-02.mp4]',
        ),
        contains(
          'Creating movie with the following custom selected videos: '
          '[2026-09-01.mp4, trip/2026-09-02.mp4]',
        ),
      ]),
    );
  });

  test('a movie asked with a transition hands the engine the style, the '
      'older-clips choice and each clip\'s cached keyframes (null for a clip '
      'not read yet) and the music; the description counts as before (the '
      'engine appends the transition part) plus music=on, and the entry '
      'records the style the engine joined with and that the music plays '
      '(D27, D28)', () async {
    await seedClip(paths, _default, LocalDay(2026, 9, 3));
    await seedClip(paths, _default, LocalDay(2026, 9, 5));
    await scan();
    const ClipKeyframes keyframes = ClipKeyframes(
      frameCount: 60,
      indices: <int>[0, 10, 50],
    );
    cacheMeta(
      '2026-09-03.mp4',
      const ClipMeta(durationMs: 2000, keyframes: keyframes),
    );

    final List<MovieBuildEvent> events = await builder
        .build(
          source: const MovieSource.month(year: 2026, month: 9),
          profile: _default,
          format: const ClipFormat.legacy(VideoOrientation.landscape),
          title: 'September 2026',
          transition: MovieTransition.crossfade,
          upgradeOlderClips: true,
          music: const MovieMusic(
            tracks: <String>['/music/a.mp3', '/music/b.mp3'],
            volume: 0.3,
          ),
        )
        .toList();

    final MovieRenderRequest request = engine.movieRequests.single;
    expect(request.transition, MovieTransition.crossfade);
    expect(request.upgradeOlderClips, isTrue);
    expect(
      request.music,
      const MovieMusic(
        tracks: <String>['/music/a.mp3', '/music/b.mp3'],
        volume: 0.3,
      ),
    );
    expect(
      request.clips.map((MovieClip clip) => clip.keyframes).toList(),
      <ClipKeyframes?>[keyframes, null],
    );
    expect(
      request.description,
      'clips=2;from=2026-09-03;to=2026-09-05;music=on',
    );
    final MovieBuilt built = events.last as MovieBuilt;
    expect(built.movie.transition, MovieTransition.crossfade);
    expect(built.movie.musicOn, isTrue);
    expect(
      sink.lines,
      contains(
        contains(
          '[CREATE MOVIE] Joining with the crossfade transition, re-encoding '
          'older clips first',
        ),
      ),
    );
    expect(
      sink.lines,
      contains(
        contains(
          "[CREATE MOVIE] Adding music: 2 tracks at 30%, over the videos' "
          'sound',
        ),
      ),
    );
  });

  test('perf guard: an all-time movie of $_bigMovie backfilled clips is '
      'planned within ${_planBudget.inMilliseconds} ms and costs zero probes '
      '(v1.7 ran one ffprobe per clip per movie, F §4.4)', () async {
    final LocalDay first = LocalDay(2013, 1, 1);
    for (int i = 0; i < _bigMovie; i++) {
      await seedClip(paths, _default, first.addDays(i));
    }
    await scan();
    for (int i = 0; i < _bigMovie; i++) {
      cacheMeta(
        ClipNameCodec.format(first.addDays(i)),
        const ClipMeta(
          durationMs: 1500,
          hasAudio: true,
          hasSubtitleStream: false,
          isOsdV15: true,
          width: 1920,
          height: 1080,
          codec: 'h264',
        ),
      );
    }
    Duration best = const Duration(days: 1);
    for (int round = 0; round <= _planRounds; round++) {
      final Stopwatch watch = Stopwatch()..start();
      Duration? planned;
      await builder
          .build(
            source: const MovieSource.preset(MoviePreset.allTime),
            profile: _default,
            format: const ClipFormat.legacy(VideoOrientation.landscape),
            title: 'All time',
          )
          .map((MovieBuildEvent event) {
            if (event is MovieBuildStarted) planned ??= watch.elapsed;
            return event;
          })
          .drain<void>();
      if (round > 0 && planned! < best) best = planned!;
    }

    expect(
      engine.movieRequests.map(
        (MovieRenderRequest request) => request.clips.length,
      ),
      everyElement(_bigMovie),
    );
    expect(engine.probedPaths, isEmpty);
    expect(best, lessThan(_planBudget));
  });

  test(
    'a range with a tag filter joins the clips the library says match, '
    'writes the filter into the description and the entry, and never '
    'asks the engine to filter (a clip not read yet is untagged to it)',
    () async {
      for (int day = 1; day <= 4; day++) {
        await seedClip(paths, _default, LocalDay(2026, 9, day));
      }
      await scan();
      clips.clipTagsKnown(<String, List<String>>{
        '2026-09-01.mp4': <String>['trip'],
        '2026-09-02.mp4': <String>['trip', 'work'],
        '2026-09-04.mp4': <String>['Trip'],
      });

      final List<MovieBuildEvent> events = await builder
          .build(
            source: MovieSource.month(
              year: 2026,
              month: 9,
              tags: TagFilter(
                anyOf: <String>{'trip'},
                noneOf: <String>{'work'},
              ),
            ),
            profile: _default,
            format: const ClipFormat.legacy(VideoOrientation.landscape),
            title: 'September 2026',
          )
          .toList();

      final MovieRenderRequest request = engine.movieRequests.single;
      expect(
        request.clips.map(
          (MovieClip clip) => paths.relativeToVideos(clip.path),
        ),
        <String>['2026-09-01.mp4', '2026-09-04.mp4'],
      );
      expect(
        request.description,
        'clips=2;from=2026-09-01;to=2026-09-04;tags=trip;without=work',
      );
      final MovieEntry movie = (events.last as MovieBuilt).movie;
      expect(movie.tags, <String>['trip']);
      expect(movie.without, <String>['work']);
      expect(movie.hasTagFilter, isTrue);
      expect((await movies.list()).single.tags, <String>[
        'trip',
      ], reason: 'the index keeps the filter');
    },
  );
}

/// A media engine whose session finishes at the very moment the user
/// cancels: it writes the movie and completes although the token is
/// cancelled.
class _CancelledAtTheEndEngine extends FakeMediaEngine {
  _CancelledAtTheEndEngine(String scratchDir) : super(scratchDir: scratchDir);

  @override
  Stream<MovieRenderEvent> renderMovie(
    MovieRenderRequest request, {
    CancelToken? cancelToken,
  }) async* {
    final File output = File(request.outputPath);
    await output.parent.create(recursive: true);
    await output.writeAsBytes(fakeVideoBytes);
    cancelToken!.cancel();
    yield MovieCompleted(outputPath: output.path, durationMs: 2000);
  }
}

/// A media engine whose movie fails after writing part of its output,
/// which the real engine promises to clean up; the builder must not rely
/// on it.
class _PartialMovieEngine extends FakeMediaEngine {
  _PartialMovieEngine({required super.scratchDir, required this.error});

  final Object error;
  final List<String> partialOutputs = <String>[];

  @override
  Stream<MovieRenderEvent> renderMovie(
    MovieRenderRequest request, {
    CancelToken? cancelToken,
  }) async* {
    movieRequests.add(request);
    yield MoviePreparing(index: 0, total: request.clips.length);
    final File partial = File(request.outputPath);
    await partial.parent.create(recursive: true);
    await partial.writeAsBytes(<int>[0, 0, 0]);
    partialOutputs.add(partial.path);
    throw error;
  }
}
