import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/commands/concat_command.dart';
import 'package:one_second_diary/core/media/commands/legacy_normalize_commands.dart';
import 'package:one_second_diary/core/media/commands/probe_commands.dart';
import 'package:one_second_diary/core/media/commands/subtitle_commands.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/policy/concat_list.dart';
import 'package:one_second_diary/core/media/policy/ffmetadata_chapters.dart';
import 'package:one_second_diary/core/media/policy/srt_codec.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/core/media/types/movie_clip.dart';
import 'package:one_second_diary/core/media/types/movie_render_event.dart';
import 'package:one_second_diary/core/media/types/movie_render_request.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/ffmpeg_statistics.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/storage_budget.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../support/support.dart';
import '../../support/track_1a/media_engine_harness.dart';
import '../../support/track_1a/scripted_ffmpeg_gateway.dart';

const ClipFormat legacy = ClipFormat.legacy(VideoOrientation.landscape);

/// The facts of a v1.5-tagged clip on the landscape canvas.
MovieClip osdClip(
  File file, {
  bool? isOsdV15 = true,
  bool? hasAudio = true,
  bool? hasSubtitleStream = false,
  int? width = 1920,
  int? height = 1080,
  String? codec = 'h264',
  int? durationMs = 1500,
  String? chapterTitle,
  int? channels,
}) => MovieClip(
  path: file.path,
  durationMs: durationMs,
  isOsdV15: isOsdV15,
  hasAudio: hasAudio,
  hasSubtitleStream: hasSubtitleStream,
  width: width,
  height: height,
  codec: codec,
  fps: 30,
  channels: channels ?? (hasAudio == true ? 1 : null),
  pixelFormat: 'yuv420p',
  chapterTitle: chapterTitle,
);

void main() {
  late AppPaths paths;
  late FakeClock clock;
  late ScriptedFfmpegGateway ffmpeg;
  late MediaEngine engine;
  late File day1;
  late File day2;
  late String movie;

  setUp(() async {
    paths = await createTestPaths();
    clock = FakeClock(DateTime(2024, 1, 5, 10));
    ffmpeg = ScriptedFfmpegGateway(clock: clock);
    engine = engineOver(ffmpeg: ffmpeg, paths: paths, clock: clock);
    day1 = await seedClip(
      paths,
      ProfileKey.defaultProfile,
      LocalDay(2024, 1, 1),
    );
    day2 = await seedClip(
      paths,
      ProfileKey.defaultProfile,
      LocalDay(2024, 1, 2),
    );
    movie = '${paths.movies}OSD-Movie-3-2024-01-05.mp4';
  });

  MovieRenderRequest request(List<MovieClip> clips) => MovieRenderRequest(
    clips: clips,
    format: const ClipFormat.legacy(VideoOrientation.landscape),
    outputPath: movie,
    title: 'January 2024',
    comment: 'profile=',
    description: 'clips=2;from=2024-01-01;to=2024-01-02',
  );

  // A movie of backfilled clips needs zero probes.
  test('joins v1.5 clips as they are: no probe, one concat with the '
      'request tags, then MovieCompleted', () async {
    final List<MovieRenderEvent> events = await engine
        .renderMovie(request(<MovieClip>[osdClip(day1), osdClip(day2)]))
        .toList();

    expect(ffmpeg.probed, isEmpty);
    final List<String> argv = ffmpeg.executed.single;
    final String listPath = argv[argv.indexOf('-i') + 1];
    expect(listPath, startsWith('${paths.scratchDir}/'));
    expect(
      argv,
      ConcatCommand.build(
        listPath: listPath,
        outputPath: movie,
        title: 'January 2024',
        comment: 'profile=',
        description: 'clips=2;from=2024-01-01;to=2024-01-02',
      ),
    );
    expect(
      ffmpeg.textInputs[listPath],
      ConcatList.content(<String>[day1.path, day2.path]),
    );
    expect(events.first, const MoviePreparing(index: 0, total: 2));
    expect(events.last, MovieCompleted(outputPath: movie, durationMs: 3000));
    expect(File(movie).existsSync(), isTrue);
    expect(Directory(paths.scratchDir).listSync(recursive: true), isEmpty);
  });

  // One MP4 chapter per clip joined, from an ffmetadata file in the job's folder; the
  // boundaries are the planned durations.
  test('clips with a chapter title are joined with a chapters input and '
      '-map_chapters 1, laid end to end over the clips that made it (a '
      'clip left out is no chapter), reported in MovieCompleted and gone '
      'with the job folder', () async {
    final File day3 = await seedClip(
      paths,
      ProfileKey.defaultProfile,
      LocalDay(2024, 1, 3),
    );
    // Day 2 is cut short.
    ffmpeg.probeResults.add(
      FakeFfmpegGateway.failure(logs: 'moov atom not found'),
    );

    final List<MovieRenderEvent> events = await engine
        .renderMovie(
          request(<MovieClip>[
            osdClip(day1, chapterTitle: 'January 1, 2024 · Berlin'),
            osdClip(day2, durationMs: null, chapterTitle: 'January 2, 2024'),
            osdClip(day3, durationMs: 2000, chapterTitle: 'January 3, 2024'),
          ]),
        )
        .toList();

    final List<String> argv = ffmpeg.executed.single;
    final String listPath = listOf(argv);
    final String chaptersPath = argv[argv.lastIndexOf('-i') + 1];
    expect(chaptersPath, startsWith('${paths.scratchDir}/'));
    expect(chaptersPath, endsWith('/${FfmetadataChapters.fileName}'));
    expect(
      argv,
      ConcatCommand.build(
        listPath: listPath,
        outputPath: movie,
        title: 'January 2024',
        comment: 'profile=',
        description: null,
        chaptersPath: chaptersPath,
      ),
    );
    const List<MovieChapter> chapters = <MovieChapter>[
      MovieChapter(startMs: 0, endMs: 1500, title: 'January 1, 2024 · Berlin'),
      MovieChapter(startMs: 1500, endMs: 3500, title: 'January 3, 2024'),
    ];
    expect(
      ffmpeg.textInputs[chaptersPath],
      FfmetadataChapters.encode(chapters),
    );
    expect(
      events.last,
      MovieCompleted(
        outputPath: movie,
        durationMs: 3500,
        skipped: const <int>[1],
        chapters: chapters,
      ),
    );
    expect(Directory(paths.scratchDir).listSync(recursive: true), isEmpty);
  });

  test('joins a sub-folder clip by its real path', () async {
    final File trip = await seedClip(
      paths,
      ProfileKey.defaultProfile,
      LocalDay(2024, 1, 3),
      subFolder: 'Backup',
    );

    await engine
        .renderMovie(request(<MovieClip>[osdClip(day1), osdClip(trip)]))
        .toList();

    expect(
      ffmpeg.textInputs[listOf(ffmpeg.executed.single)],
      ConcatList.content(<String>[
        day1.path,
        '${paths.videos}Backup/2024-01-03.mp4',
      ]),
    );
  });

  // MovieBuilder renders into <scratchDir>/movie-<µs>/<name>, a folder
  // nobody has made. ffmpeg never creates the folder of its output, and
  // init()'s scratch sweep would delete one made before the first job, so
  // the engine makes it inside the job.
  test('makes the folder of the output before the concat, as ffmpeg '
      'cannot', () async {
    movie = '${paths.scratchDir}/movie-1/OSD-Movie-3-2024-01-05.mp4';
    bool? folderWasThere;
    ffmpeg.onExecute = (List<String> arguments) async {
      if (arguments.contains(movie)) {
        folderWasThere = await File(movie).parent.exists();
      }
      await ffmpeg.writeOutput(arguments);
    };

    await engine
        .renderMovie(request(<MovieClip>[osdClip(day1), osdClip(day2)]))
        .toList();

    expect(folderWasThere, isTrue);
  });

  test('caller errors end the stream with an ArgumentError, before any work: '
      'fewer than two clips, an output that already exists, which is left as '
      'it was', () async {
    await expectLater(
      engine.renderMovie(request(<MovieClip>[osdClip(day1)])),
      emitsError(isArgumentError),
    );

    final File existing = File(movie)
      ..createSync(recursive: true)
      ..writeAsBytesSync(<int>[4, 2]);
    await expectLater(
      engine.renderMovie(request(<MovieClip>[osdClip(day1), osdClip(day2)])),
      emitsError(isArgumentError),
    );

    expect(ffmpeg.executed, isEmpty);
    expect(existing.readAsBytesSync(), <int>[4, 2]);
  });

  // A clip the backfill has not reached costs one probe inside the engine;
  // null means unknown, never guessed.
  test('probes only the clips with an unknown fact, once each', () async {
    ffmpeg.probeOutputs[day2.path] = v15Json(durationMs: 2000);

    final List<MovieRenderEvent> events = await engine
        .renderMovie(
          request(<MovieClip>[
            osdClip(day1),
            osdClip(day2, durationMs: null, hasSubtitleStream: null),
          ]),
        )
        .toList();

    expect(ffmpeg.probed, <List<String>>[ProbeCommands.streams(day2.path)]);
    expect(ffmpeg.executed.single, contains(movie), reason: 'only the concat');
    expect(events.last, MovieCompleted(outputPath: movie, durationMs: 3500));
  });

  // The library leaves out the private clips it knows; one nobody has read
  // yet (right after a reinstall) is caught by the probe it needs anyway.
  test('a movie that excludes private clips leaves out a probed clip whose '
      'file says it is private, and says which; one that includes them '
      'joins it', () async {
    final File day3 = await seedClip(
      paths,
      ProfileKey.defaultProfile,
      LocalDay(2024, 1, 3),
    );
    ffmpeg.probeOutputs[day2.path] = v15Json(description: 'private=1');
    ffmpeg.probeOutputs[day3.path] = v15Json();
    List<MovieClip> clips() => <MovieClip>[
      osdClip(day1),
      osdClip(day2, durationMs: null),
      osdClip(day3, durationMs: null),
    ];

    final MovieRenderRequest excluding = MovieRenderRequest(
      clips: clips(),
      format: const ClipFormat.legacy(VideoOrientation.landscape),
      outputPath: movie,
      title: 'January 2024',
      comment: 'profile=',
      description: 'clips=3;from=2024-01-01;to=2024-01-03',
      excludePrivate: true,
    );
    final List<MovieRenderEvent> events = await engine
        .renderMovie(excluding)
        .toList();

    expect(
      ffmpeg.textInputs[listOf(ffmpeg.executed.single)],
      ConcatList.content(<String>[day1.path, day3.path]),
    );
    // The description counts every clip asked for: with one left out as
    // private the movie carries none, as with one that cannot be read.
    expect(
      ffmpeg.executed.single.where((String a) => a.startsWith('description=')),
      isEmpty,
    );
    expect(
      events.last,
      MovieCompleted(
        outputPath: movie,
        durationMs: 3000,
        leftOutPrivate: const <int>[1],
      ),
    );

    // Included: joined like any other clip.
    File(movie).deleteSync();
    ffmpeg.executed.clear();
    await engine.renderMovie(request(clips())).toList();

    expect(
      ffmpeg.textInputs[listOf(ffmpeg.executed.single)],
      ConcatList.content(<String>[day1.path, day2.path, day3.path]),
    );
  });

  group('legacy clips', () {
    // Steps A to F on a private copy: canvas + 30 fps (with the keyframes, since the probe
    // told the length), then step B's probe of the copy, mono AAC (it has audio), an empty
    // subtitle stream (it has none), the tags.
    test('are normalised on a private copy with v1.7 steps A to F, kept in '
        'the cache; the original is never touched', () async {
      ffmpeg.otherProbeOutput = v15Json(artist: '');
      final List<String> clipsBefore = listFiles(paths.videos);

      await engine
          .renderMovie(
            request(<MovieClip>[
              osdClip(day1, width: 1280, height: 720),
              osdClip(day2),
            ]),
          )
          .toList();

      final List<List<String>> steps = ffmpeg.executed;
      final String copy1 = ScriptedFfmpegGateway.outputOf(steps[0])!;
      final String copy2 = ScriptedFfmpegGateway.outputOf(steps[1])!;
      expect(copy1, startsWith('${paths.scratchDir}/'));
      expect(steps.sublist(0, 4), <List<String>>[
        LegacyNormalizeCommands.canvas(
          source: day1.path,
          output: copy1,
          format: legacy,
          encoder: VideoEncoder.libx264,
          durationMs: 1500,
        ),
        LegacyNormalizeCommands.audio(
          input: copy1,
          output: copy2,
          format: legacy,
        ),
        LegacyNormalizeCommands.emptySubtitles(
          input: copy1,
          subtitles: steps[2][3],
          output: copy2,
        ),
        LegacyNormalizeCommands.tags(
          input: copy1,
          output: copy2,
          format: legacy,
        ),
      ]);
      expect(ffmpeg.probed, <List<String>>[ProbeCommands.streams(copy1)]);
      expect(ffmpeg.textInputs[steps[2][3]], SrtCodec.emptyCue);

      final String list = ffmpeg.textInputs[listOf(steps.last)]!;
      final String cached = list.split('\r\n').first;
      expect(cached, startsWith("file '${paths.normalizedDir}/"));
      expect(list, endsWith("file '${day2.path}'"));
      expect(day1.readAsBytesSync(), fakeVideoBytes, reason: 'original kept');
      expect(
        listFiles(paths.videos),
        <String>[...clipsBefore, movie]..sort(),
        reason: 'temps never in DCIM (invariant 14)',
      );
    });

    test(
      'the cache is trimmed to its cap after a movie, oldest first',
      () async {
        ffmpeg.otherProbeOutput = v15Json(artist: '');
        // A stale entry just over the cap (sparse: nothing is really
        // written), used long ago.
        final File stale = File('${paths.normalizedDir}/stale-landscape.mp4')
          ..createSync(recursive: true);
        (stale.openSync(mode: FileMode.write)
              ..truncateSync(StorageBudget.cacheCapMinBytes + (100 << 20)))
            .closeSync();
        stale.setLastModifiedSync(DateTime(2020));

        await engine
            .renderMovie(
              request(<MovieClip>[
                osdClip(day1, width: 1280, height: 720),
                osdClip(day2),
              ]),
            )
            .toList();

        expect(stale.existsSync(), isFalse);
        expect(listFiles(paths.normalizedDir), hasLength(1), reason: 'day 1');
      },
    );

    test(
      'are normalised once: the next movie reuses the cached copy',
      () async {
        ffmpeg.otherProbeOutput = v15Json(artist: '');
        final List<MovieClip> clips = <MovieClip>[
          osdClip(day1, width: 1280, height: 720),
          osdClip(day2),
        ];
        await engine.renderMovie(request(clips)).toList();
        final String firstList =
            ffmpeg.textInputs[listOf(ffmpeg.executed.last)]!;
        ffmpeg.executed.clear();
        ffmpeg.probed.clear();

        final String second = '${paths.movies}OSD-Movie-4-2024-01-05.mp4';
        await engine
            .renderMovie(
              MovieRenderRequest(
                clips: clips,
                format: const ClipFormat.legacy(VideoOrientation.landscape),
                outputPath: second,
                title: null,
                comment: 'profile=',
              ),
            )
            .toList();

        expect(ffmpeg.probed, isEmpty);
        expect(ffmpeg.executed.single, contains(second), reason: 'concat only');
        expect(ffmpeg.textInputs[listOf(ffmpeg.executed.single)], firstList);
      },
    );

    test(
      'an edited clip is normalised again, never joined from a stale copy',
      () async {
        ffmpeg.otherProbeOutput = v15Json(artist: '');
        final List<MovieClip> clips = <MovieClip>[
          osdClip(day1, width: 1280, height: 720),
          osdClip(day2),
        ];
        await engine.renderMovie(request(clips)).toList();
        day1.writeAsBytesSync(<int>[...fakeVideoBytes, 1]);
        ffmpeg.executed.clear();

        await engine
            .renderMovie(
              MovieRenderRequest(
                clips: clips,
                format: const ClipFormat.legacy(VideoOrientation.landscape),
                outputPath: '${paths.movies}OSD-Movie-4-2024-01-05.mp4',
                title: null,
                comment: 'profile=',
              ),
            )
            .toList();

        expect(ffmpeg.executed.first.sublist(0, 2), <String>['-i', day1.path]);
      },
    );

    // A clip without audio (the native camera without a microphone) would break the concat.
    // Its video matches the format, so the cheaper path runs: no step A, no probe of a copy;
    // the silent track is added to the clip itself (step D), the tags rewritten (F), its
    // subtitle stream kept.
    test('a clip without audio takes the audio-only path: step D on the '
        'clip itself, then F; the video is never re-encoded', () async {
      await engine
          .renderMovie(
            request(<MovieClip>[
              osdClip(day1, hasSubtitleStream: true),
              osdClip(day2, hasAudio: false, hasSubtitleStream: true),
            ]),
          )
          .toList();

      final List<List<String>> steps = ffmpeg.executed;
      final String next = ScriptedFfmpegGateway.outputOf(steps[0])!;
      expect(next, startsWith('${paths.scratchDir}/'));
      expect(next, endsWith('-next.mp4'));
      final String copy = next.replaceFirst('-next.mp4', '.mp4');
      expect(steps.sublist(0, steps.length - 1), <List<String>>[
        LegacyNormalizeCommands.silentAudio(
          input: day2.path,
          output: next,
          durationMs: 1500,
          format: legacy,
        ),
        LegacyNormalizeCommands.tags(input: copy, output: next, format: legacy),
      ], reason: 'steps D and F, then the concat');
      expect(ffmpeg.probed, isEmpty, reason: 'the facts were known');
      expect(
        steps.where((List<String> argv) => argv.contains('-vf')),
        isEmpty,
        reason: 'no re-encode',
      );
      expect(steps.last, contains(movie));
      final String list = ffmpeg.textInputs[listOf(steps.last)]!;
      expect(
        list.split('\r\n')[1],
        startsWith("file '${paths.normalizedDir}/"),
      );
      expect(day2.readAsBytesSync(), fakeVideoBytes, reason: 'original kept');
    });

    // A stereo clip in a mono profile: the audio alone is re-encoded (step C on the clip),
    // the empty subtitle stream added (E) and the tags rewritten (F). Without a transition
    // nobody asks about keyframes, and the copy is cached without the `-kf` promise it does
    // not make.
    test('a clip whose layout differs takes the audio-only path: steps C, '
        'E and F on the clip itself', () async {
      await engine
          .renderMovie(
            request(<MovieClip>[osdClip(day1, channels: 2), osdClip(day2)]),
          )
          .toList();

      final List<List<String>> steps = ffmpeg.executed;
      final String next = ScriptedFfmpegGateway.outputOf(steps[0])!;
      final String copy = next.replaceFirst('-next.mp4', '.mp4');
      expect(steps.sublist(0, steps.length - 1), <List<String>>[
        LegacyNormalizeCommands.audio(
          input: day1.path,
          output: next,
          format: legacy,
        ),
        LegacyNormalizeCommands.emptySubtitles(
          input: copy,
          subtitles: steps[1][3],
          output: next,
        ),
        LegacyNormalizeCommands.tags(input: copy, output: next, format: legacy),
      ], reason: 'steps C, E and F, then the concat');
      expect(ffmpeg.probed, isEmpty);
      expect(ffmpeg.textInputs[steps[1][3]], SrtCodec.emptyCue);
      final String first = ffmpeg.textInputs[listOf(steps.last)]!.split(
        '\r\n',
      )[0];
      expect(first, startsWith("file '${paths.normalizedDir}/"));
      expect(first, isNot(endsWith("-kf.mp4'")));
    });

    // A movie of another format normalises into that format, and a copy made for one format
    // never serves another.
    test('a legacy clip in a 4K60 HEVC stereo movie is normalised into '
        'that format with its encoder, under a key of its own', () async {
      const ClipFormat ultra = ClipFormat(
        tier: ResolutionTier.p2160,
        orientation: VideoOrientation.landscape,
        codec: VideoCodec.hevc,
        fps: FrameRate.f60,
        channels: AudioChannels.stereo,
        range: DynamicRange.sdr,
      );
      ffmpeg.encodersOutput =
          ' V....D libx264              libx264 H.264\n'
          ' V....D hevc_mediacodec      MediaCodec HEVC encoder\n';
      ffmpeg.otherProbeOutput = v15Json();

      await engine
          .renderMovie(
            MovieRenderRequest(
              clips: <MovieClip>[osdClip(day1), osdClip(day2)],
              format: ultra,
              outputPath: movie,
              title: null,
              comment: 'profile=Ultra',
            ),
          )
          .toList();

      final List<List<String>> steps = ffmpeg.executed;
      final String copy1 = ScriptedFfmpegGateway.outputOf(steps[0])!;
      expect(
        steps[0],
        LegacyNormalizeCommands.canvas(
          source: day1.path,
          output: copy1,
          format: ultra,
          encoder: VideoEncoder.hevcMediaCodec,
          durationMs: 1500,
        ),
      );
      expect(steps.last, contains('60'), reason: '-r 60 on the concat');
      final String list = ffmpeg.textInputs[listOf(steps.last)]!;
      expect(list, contains('2160p60-hevc-stereo-sdr-landscape'));
      expect(list, isNot(contains(day1.path)));
    });
  });

  // The concat takes the first clip's streams, so [no subtitles, subtitles]
  // would lose every subtitle: the first clip is remuxed with the
  // placeholder cue.
  group('first-clip subtitles', () {
    test('a first clip without subtitles is joined through a copy with an '
        'empty subtitle stream when a later clip has subtitles', () async {
      await engine
          .renderMovie(
            request(<MovieClip>[
              osdClip(day1),
              osdClip(day2, hasSubtitleStream: true),
            ]),
          )
          .toList();

      final List<String> remux = ffmpeg.executed.first;
      final String copy = ScriptedFfmpegGateway.outputOf(remux)!;
      expect(
        remux,
        SubtitleCommands.remux(
          clip: day1.path,
          subtitles: remux[3],
          output: copy,
        ),
      );
      expect(copy, startsWith('${paths.scratchDir}/'));
      expect(ffmpeg.textInputs[remux[3]], SrtCodec.emptyCue);
      expect(
        ffmpeg.textInputs[listOf(ffmpeg.executed.last)],
        ConcatList.content(<String>[copy, day2.path]),
      );
      expect(day1.readAsBytesSync(), fakeVideoBytes);
    });
  });

  group('progress', () {
    FfmpegStatistics at(int timeMs) => FfmpegStatistics(
      timeMs: timeMs,
      videoFrameNumber: 0,
      size: 0,
      speed: 9,
    );

    test('the concat reports its output time over the summed durations and '
        'the clip being copied', () async {
      final File day3 = await seedClip(
        paths,
        ProfileKey.defaultProfile,
        LocalDay(2024, 1, 3),
      );
      ffmpeg.statistics = <FfmpegStatistics>[
        at(500),
        at(1500),
        at(3000),
        at(4200),
      ];

      final List<MovieRenderEvent> events = await engine
          .renderMovie(
            request(<MovieClip>[
              osdClip(day1, durationMs: 1000),
              osdClip(day2, durationMs: 2000),
              osdClip(day3, durationMs: 1000),
            ]),
          )
          .toList();

      expect(events, <MovieRenderEvent>[
        const MoviePreparing(index: 0, total: 3),
        const MovieConcatenating(fraction: 0.125, currentIndex: 0),
        const MovieConcatenating(fraction: 0.375, currentIndex: 1),
        const MovieConcatenating(fraction: 0.75, currentIndex: 2),
        const MovieConcatenating(fraction: 0.999, currentIndex: 2),
        MovieCompleted(outputPath: movie, durationMs: 4000),
      ]);
    });
  });

  group('cancel', () {
    /// Waits until the concat (the only session of two v1.5 clips) runs
    /// and has written part of the movie.
    Future<void> concatRunning() async {
      while (ffmpeg.heldSessions.isEmpty || !File(movie).existsSync()) {
        await pumpEventQueue();
      }
    }

    test(
      'through the token: CancelledException, no partial movie, no temps',
      () async {
        ffmpeg.holdExecutions = true;
        final CancelToken token = CancelToken();
        final Future<List<MovieRenderEvent>> making = engine
            .renderMovie(
              request(<MovieClip>[osdClip(day1), osdClip(day2)]),
              cancelToken: token,
            )
            .toList();
        await concatRunning();

        token.cancel();

        await expectLater(making, throwsA(isA<CancelledException>()));
        expect(ffmpeg.cancelledSessions, <int>[1]);
        expect(File(movie).existsSync(), isFalse);
        expect(Directory(paths.scratchDir).listSync(recursive: true), isEmpty);
      },
    );

    test(
      'through the subscription: the session stops and nothing is left',
      () async {
        ffmpeg.holdExecutions = true;
        final StreamSubscription<MovieRenderEvent> subscription = engine
            .renderMovie(request(<MovieClip>[osdClip(day1), osdClip(day2)]))
            .listen((_) {});
        await concatRunning();

        await subscription.cancel();

        expect(ffmpeg.cancelledSessions, <int>[1]);
        expect(File(movie).existsSync(), isFalse);
        expect(Directory(paths.scratchDir).listSync(recursive: true), isEmpty);
      },
    );

    test('a movie cancelled while waiting for its turn runs nothing', () async {
      ffmpeg.holdExecutions = true;
      final Future<String> remux = engine.remuxSubtitles(
        clipPath: day1.path,
        text: 'Hi',
        durationMs: 1500,
      );
      while (ffmpeg.heldSessions.isEmpty) {
        await pumpEventQueue();
      }
      final StreamSubscription<MovieRenderEvent> subscription = engine
          .renderMovie(request(<MovieClip>[osdClip(day1), osdClip(day2)]))
          .listen((_) {});
      await pumpEventQueue();

      await subscription.cancel();
      ffmpeg.releaseHeld();
      await remux;
      // A job queued after the movie: when it is done, the movie had its
      // turn.
      ffmpeg.probeOutputs[day2.path] = v15Json();
      await engine.probe(day2.path);

      expect(
        ffmpeg.executed.where((List<String> a) => a.contains(movie)),
        isEmpty,
      );
      expect(File(movie).existsSync(), isFalse);
    });
  });

  // One clip cut short (no moov atom) must not fail the whole movie.
  group('clips that cannot be read', () {
    test('a clip ffprobe cannot open and one without video are left out: the '
        'rest is joined, without the description that counted them, and the '
        'movie says which', () async {
      final File day3 = await seedClip(
        paths,
        ProfileKey.defaultProfile,
        LocalDay(2024, 1, 3),
      );
      final File day4 = await seedClip(
        paths,
        ProfileKey.defaultProfile,
        LocalDay(2024, 1, 4),
      );
      // Day 1 is cut short; day 3 has only sound.
      ffmpeg.probeResults.add(
        FakeFfmpegGateway.failure(logs: 'moov atom not found'),
      );
      ffmpeg.probeOutputs[day3.path] =
          '{"streams": [{"codec_type": "audio"}], '
          '"format": {"duration": "1.5"}}';

      final List<MovieRenderEvent> events = await engine
          .renderMovie(
            request(<MovieClip>[
              osdClip(day1, durationMs: null),
              osdClip(day2),
              osdClip(day3, width: null, height: null, codec: null),
              osdClip(day4),
            ]),
          )
          .toList();

      final List<String> concat = ffmpeg.executed.single;
      expect(
        ffmpeg.textInputs[listOf(concat)],
        ConcatList.content(<String>[day2.path, day4.path]),
      );
      expect(concat, isNot(contains(startsWith('description='))));
      expect(
        events.last,
        MovieCompleted(
          outputPath: movie,
          durationMs: 3000,
          skipped: const <int>[0, 2],
        ),
      );
    });

    test('with fewer than two clips left, the stream ends with a '
        'NotEnoughClipsException counting those left out, and nothing is '
        'joined', () async {
      ffmpeg.probeResults.add(
        FakeFfmpegGateway.failure(logs: 'moov atom not found'),
      );

      await expectLater(
        engine.renderMovie(
          request(<MovieClip>[osdClip(day1, durationMs: null), osdClip(day2)]),
        ),
        emitsThrough(
          emitsError(
            isA<NotEnoughClipsException>().having(
              (NotEnoughClipsException e) => e.skipped,
              'skipped',
              1,
            ),
          ),
        ),
      );
      expect(ffmpeg.executed, isEmpty);
      expect(File(movie).existsSync(), isFalse);
    });
  });

  group('failure', () {
    test('a failed concat ends the stream with VideoProcessingException and '
        'leaves no partial movie', () async {
      ffmpeg.executeResults.add(
        FakeFfmpegGateway.failure(returnCode: 1, logs: 'Non-monotonous DTS'),
      );

      await expectLater(
        engine.renderMovie(request(<MovieClip>[osdClip(day1), osdClip(day2)])),
        emitsThrough(
          emitsError(
            isA<VideoProcessingException>().having(
              (VideoProcessingException e) => e.logTail,
              'logTail',
              'Non-monotonous DTS',
            ),
          ),
        ),
      );
      expect(File(movie).existsSync(), isFalse);
      expect(Directory(paths.scratchDir).listSync(recursive: true), isEmpty);
    });

    test('a failed normalisation step fails the movie at once, with no movie '
        'and no cached copy', () async {
      ffmpeg.answer = (List<String> argv) =>
          argv.contains('-vf') ? FakeFfmpegGateway.failure() : null;

      await expectLater(
        engine.renderMovie(
          request(<MovieClip>[
            osdClip(day1, width: 1280, height: 720),
            osdClip(day2),
          ]),
        ),
        emitsThrough(emitsError(isA<VideoProcessingException>())),
      );
      expect(
        ffmpeg.executed.where((List<String> a) => a.contains(movie)),
        isEmpty,
      );
      expect(File(movie).existsSync(), isFalse);
      expect(listFiles(paths.cacheDir), isEmpty);
    });

    test('cancelled while normalising: no movie, no cached copy', () async {
      ffmpeg.holdExecutions = true;
      final CancelToken token = CancelToken();
      final Future<List<MovieRenderEvent>> making = engine
          .renderMovie(
            request(<MovieClip>[
              osdClip(day1, width: 1280, height: 720),
              osdClip(day2),
            ]),
            cancelToken: token,
          )
          .toList();
      while (ffmpeg.heldSessions.isEmpty) {
        await pumpEventQueue();
      }

      token.cancel();

      await expectLater(making, throwsA(isA<CancelledException>()));
      expect(File(movie).existsSync(), isFalse);
      expect(listFiles(paths.cacheDir), isEmpty);
    });
  });
}

/// ffprobe JSON of a v1.5 clip on the landscape canvas.
String v15Json({
  int durationMs = 1500,
  bool subtitles = false,
  bool audio = true,
  String artist = 'One Second Diary (v1.5)',
  String codec = 'h264',
  int width = 1920,
  int height = 1080,
  String? description,
}) =>
    '''
{"streams": [
  {"codec_type": "video", "codec_name": "$codec", "width": $width,
   "height": $height, "r_frame_rate": "30/1", "pix_fmt": "yuv420p"}
  ${audio ? ', {"codec_type": "audio", "codec_name": "aac", "channels": 1}' : ''}
  ${subtitles ? ', {"codec_type": "subtitle", "codec_name": "mov_text"}' : ''}
 ],
 "format": {"duration": "${durationMs / 1000}", "tags": {"artist": "$artist"${description == null ? '' : ', "description": "$description"'}}}}
''';

/// Every file under [folder], sorted.
List<String> listFiles(String folder) => <String>[
  for (final FileSystemEntity entity in Directory(
    folder,
  ).listSync(recursive: true))
    if (entity is File) entity.path,
]..sort();

/// The concat list path of a concat [argv].
String listOf(List<String> argv) => argv[argv.indexOf('-i') + 1];
