import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/commands/concat_command.dart';
import 'package:one_second_diary/core/media/commands/legacy_normalize_commands.dart';
import 'package:one_second_diary/core/media/commands/probe_commands.dart';
import 'package:one_second_diary/core/media/commands/transition_commands.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/policy/concat_list.dart';
import 'package:one_second_diary/core/media/policy/ffmetadata_chapters.dart';
import 'package:one_second_diary/core/media/policy/srt_codec.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/core/media/types/movie_clip.dart';
import 'package:one_second_diary/core/media/types/movie_render_event.dart';
import 'package:one_second_diary/core/media/types/movie_render_request.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/ffmpeg_statistics.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../support/support.dart';
import '../../support/track_1a/media_engine_harness.dart';
import '../../support/track_1a/scripted_ffmpeg_gateway.dart';

/// The keyframes of a clip saved with cut keyframes, [frames] long.
ClipKeyframes saved(int frames) =>
    ClipKeyframes(frameCount: frames, indices: <int>[0, 10, frames - 10]);

/// The keyframes of a clip saved by libx264 without them.
ClipKeyframes older(int frames) =>
    ClipKeyframes(frameCount: frames, indices: <int>[0]);

/// A keyframe probe's output for [keyframes].
String keyframeCsv(ClipKeyframes keyframes) => <String>[
  for (int frame = 0; frame < keyframes.frameCount; frame++)
    '${(frame / 30).toStringAsFixed(6)},'
        '${keyframes.indices.contains(frame) ? 'K__' : '___'}',
].join('\n');

/// A v1.5 clip on the landscape canvas, [frames] long, with [keyframes]
/// (null: unknown to the request).
MovieClip clip(
  File file, {
  required int frames,
  ClipKeyframes? keyframes,
  bool isOsdV15 = true,
  String? chapterTitle,
  int channels = 1,
}) => MovieClip(
  path: file.path,
  durationMs: (frames * 1000 / 30).round(),
  isOsdV15: isOsdV15,
  hasAudio: true,
  hasSubtitleStream: false,
  width: 1920,
  height: 1080,
  codec: 'h264',
  fps: 30,
  channels: channels,
  pixelFormat: 'yuv420p',
  chapterTitle: chapterTitle,
  keyframes: keyframes,
);

/// ffprobe's streams of a normalised copy on the legacy canvas, mono,
/// [seconds] long.
String copyJson(double seconds) =>
    '{"streams": [{"codec_type": "video", "codec_name": "h264", '
    '"width": 1920, "height": 1080, "r_frame_rate": "30/1", '
    '"pix_fmt": "yuv420p"}, {"codec_type": "audio", "codec_name": "aac", '
    '"channels": 1}], "format": {"duration": "$seconds"}}';

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

  MovieRenderRequest request(
    List<MovieClip> clips, {
    MovieTransition? transition = MovieTransition.crossfade,
    bool upgradeOlderClips = false,
  }) => MovieRenderRequest(
    clips: clips,
    format: const ClipFormat.legacy(VideoOrientation.landscape),
    outputPath: movie,
    title: 'January 2024',
    comment: 'profile=',
    description: 'clips=2;from=2024-01-01;to=2024-01-02',
    transition: transition,
    upgradeOlderClips: upgradeOlderClips,
  );

  /// The job folder of the first session's output.
  String jobOf(List<List<String>> executed) =>
      File(ScriptedFfmpegGateway.outputOf(executed.first)!).parent.path;

  // Two cut-able clips: the first's body up to its tail keyframe, the segment of its tail
  // and the second's head, the second's body from its head keyframe, the audio in one
  // pass, then the concat of the three files with exact durations and the audio track. No
  // probe: the request knew the keyframes. The movie is 8 frames shorter than the clips.
  test('joins two cut-able clips with one transition: body, segment, body, '
      'audio, concat with the audio track and duration lines', () async {
    final List<MovieRenderEvent> events = await engine
        .renderMovie(
          request(<MovieClip>[
            clip(day1, frames: 60, keyframes: saved(60)),
            clip(day2, frames: 45, keyframes: saved(45)),
          ]),
        )
        .toList();

    expect(ffmpeg.probed, isEmpty);
    final List<List<String>> steps = ffmpeg.executed;
    final String job = jobOf(steps);
    expect(job, startsWith('${paths.scratchDir}/'));
    final String listPath = steps.last[steps.last.indexOf('-i') + 1];
    expect(steps, <List<String>>[
      TransitionCommands.body(
        input: day1.path,
        output: '$job/body-0.mp4',
        headCut: 0,
        tailCut: 50,
        fps: FrameRate.f30,
      ),
      TransitionCommands.segment(
        before: day1.path,
        beforeFrameCount: 60,
        beforeTailCut: 50,
        after: day2.path,
        afterHeadCut: 10,
        emptySubtitles: '$job/empty.srt',
        transition: MovieTransition.crossfade,
        format: const ClipFormat.legacy(VideoOrientation.landscape),
        encoder: VideoEncoder.libx264,
        output: '$job/segment-0.mp4',
      ),
      TransitionCommands.body(
        input: day2.path,
        output: '$job/body-1.mp4',
        headCut: 10,
        tailCut: null,
        fps: FrameRate.f30,
      ),
      TransitionCommands.audio(
        inputs: <AudioInput>[
          (path: day1.path, seconds: '2.000000'),
          (path: day2.path, seconds: '1.500000'),
        ],
        crossfades: const <bool>[true],
        output: '$job/audio.m4a',
        toAac: true,
        format: const ClipFormat.legacy(VideoOrientation.landscape),
      ),
      ConcatCommand.build(
        listPath: listPath,
        outputPath: movie,
        title: 'January 2024',
        comment: 'profile=',
        description: 'clips=2;from=2024-01-01;to=2024-01-02;transition=fade',
        audioPath: '$job/audio.m4a',
      ),
    ]);
    expect(ffmpeg.textInputs['$job/empty.srt'], SrtCodec.emptyCue);
    expect(
      ffmpeg.textInputs[listPath],
      ConcatList.content(
        <String>['$job/body-0.mp4', '$job/segment-0.mp4', '$job/body-1.mp4'],
        durations: <String>['1.666667', '0.400000', '1.166667'],
      ),
    );
    expect(events.first, const MoviePreparing(index: 0, total: 2));
    expect(
      events.last,
      MovieCompleted(outputPath: movie, durationMs: 3233, transitions: 1),
    );
    expect(File(movie).existsSync(), isTrue);
    expect(Directory(paths.scratchDir).listSync(recursive: true), isEmpty);
  });

  // The keyframes of a clip the request does not know are probed once; a
  // clip that cannot be cut (one keyframe) makes a hard cut, and a movie
  // without a single transition is joined exactly as one made without.
  test('probes unknown keyframes; with no boundary to cut, joins as a '
      'movie without transitions, counting the hard cuts', () async {
    ffmpeg.keyframeOutputs[day1.path] = keyframeCsv(saved(60));
    ffmpeg.keyframeOutputs[day2.path] = keyframeCsv(older(45));

    final List<MovieRenderEvent> events = await engine
        .renderMovie(
          request(<MovieClip>[
            clip(day1, frames: 60),
            clip(day2, frames: 45, chapterTitle: 'January 2, 2024'),
          ]),
        )
        .toList();

    expect(ffmpeg.probed, <List<String>>[
      ProbeCommands.keyframes(day1.path),
      ProbeCommands.keyframes(day2.path),
    ]);
    final List<String> concat = ffmpeg.executed.single;
    final String listPath = concat[concat.indexOf('-i') + 1];
    final String chaptersPath = concat[concat.lastIndexOf('-i') + 1];
    expect(
      concat,
      ConcatCommand.build(
        listPath: listPath,
        outputPath: movie,
        title: 'January 2024',
        comment: 'profile=',
        description: 'clips=2;from=2024-01-01;to=2024-01-02',
        chaptersPath: chaptersPath,
      ),
    );
    expect(
      ffmpeg.textInputs[listPath],
      ConcatList.content(<String>[day1.path, day2.path]),
    );
    expect(
      events.last,
      MovieCompleted(
        outputPath: movie,
        durationMs: 3500,
        chapters: const <MovieChapter>[
          MovieChapter(startMs: 2000, endMs: 3500, title: 'January 2, 2024'),
        ],
        hardCuts: 1,
      ),
    );
  });

  // The older clip is re-encoded through step A with the cut keyframes into the
  // normalised-copy cache, its copy probed, and the transition made from the copy. The
  // original is never touched.
  test('with upgradeOlderClips, an older clip is re-encoded into a cut-able '
      'cached copy that the transition is made from', () async {
    ffmpeg.otherKeyframeOutput = keyframeCsv(saved(45));

    final List<MovieRenderEvent> events = await engine
        .renderMovie(
          request(<MovieClip>[
            clip(day1, frames: 60, keyframes: saved(60)),
            clip(day2, frames: 45, keyframes: older(45)),
          ], upgradeOlderClips: true),
        )
        .toList();

    final List<List<String>> steps = ffmpeg.executed;
    final String job = jobOf(steps);
    expect(
      steps.first,
      LegacyNormalizeCommands.canvas(
        source: day2.path,
        output: '$job/upgrade-1.mp4',
        format: const ClipFormat.legacy(VideoOrientation.landscape),
        encoder: VideoEncoder.libx264,
        durationMs: 1500,
      ),
    );
    final String copy = ffmpeg.probed.single.last;
    expect(copy, startsWith('${paths.normalizedDir}/'));
    expect(copy, endsWith('-kf.mp4'));
    expect(ffmpeg.probed.single, ProbeCommands.keyframes(copy));
    expect(
      steps[2],
      TransitionCommands.segment(
        before: day1.path,
        beforeFrameCount: 60,
        beforeTailCut: 50,
        after: copy,
        afterHeadCut: 10,
        emptySubtitles: '$job/empty.srt',
        transition: MovieTransition.crossfade,
        format: const ClipFormat.legacy(VideoOrientation.landscape),
        encoder: VideoEncoder.libx264,
        output: '$job/segment-0.mp4',
      ),
    );
    expect(steps[3].sublist(0, 4), <String>[
      '-ss',
      '0.333333',
      '-i',
      copy,
    ], reason: 'the second body is cut from the copy');
    expect(
      events.last,
      MovieCompleted(outputPath: movie, durationMs: 3233, transitions: 1),
    );
    expect(day2.readAsBytesSync(), fakeVideoBytes);
    expect(File(copy).existsSync(), isTrue, reason: 'kept for the next movie');
  });

  // A stereo clip in a mono movie normally takes the audio-only path (video stream-copied),
  // whose copy carries the clip's own keyframes: an older clip's copy could not be cut. With
  // a transition, such a clip goes through the full normalisation (step A writes the cut
  // keyframes, then C, E, F), its copy is probed, and the boundary fades. The original is
  // never touched.
  test('a stereo-in-mono clip lacking the cut keyframes is normalised in '
      'full for a transition, and the boundary beside it fades', () async {
    ffmpeg.probeOutputs['normalize-0.mp4'] = copyJson(2);
    ffmpeg.otherKeyframeOutput = keyframeCsv(saved(60));
    const ClipFormat legacy = ClipFormat.legacy(VideoOrientation.landscape);

    final List<MovieRenderEvent> events = await engine
        .renderMovie(
          request(<MovieClip>[
            clip(day1, frames: 60, keyframes: older(60), channels: 2),
            clip(day2, frames: 45, keyframes: saved(45)),
          ]),
        )
        .toList();

    final List<List<String>> steps = ffmpeg.executed;
    final String job = jobOf(steps);
    final String copy = '$job/normalize-0.mp4';
    expect(
      steps.first,
      LegacyNormalizeCommands.canvas(
        source: day1.path,
        output: copy,
        format: legacy,
        encoder: VideoEncoder.libx264,
        durationMs: 2000,
      ),
      reason: 'step A, not the audio-only path',
    );
    expect(
      steps[1],
      LegacyNormalizeCommands.audio(
        input: copy,
        output: '$job/normalize-0-next.mp4',
        format: legacy,
      ),
    );
    final String cached = ffmpeg.probed[1].last;
    expect(ffmpeg.probed, <List<String>>[
      ProbeCommands.streams(copy),
      ProbeCommands.keyframes(cached),
    ], reason: 'the copy\'s facts, then its keyframes for the cut');
    expect(cached, startsWith('${paths.normalizedDir}/'));
    expect(cached, endsWith('-kf.mp4'), reason: 'kept as cut-able');
    expect(
      steps.map(ScriptedFfmpegGateway.outputOf),
      contains('$job/segment-0.mp4'),
      reason: 'the crossfade is rendered',
    );
    expect(
      events.last,
      MovieCompleted(outputPath: movie, durationMs: 3233, transitions: 1),
    );
    expect(day1.readAsBytesSync(), fakeVideoBytes);
  });

  // A middle clip that cannot be cut keeps its neighbours' sides uncut
  // and joins as it is; its chapter starts where the fade before it would
  // not be: at the hard cut. The clip before it keeps its whole end.
  test('a mix: transitions only where both sides can be cut; an uncut clip '
      'joins by its own path; chapters at the fades', () async {
    final File day3 = await seedClip(
      paths,
      ProfileKey.defaultProfile,
      LocalDay(2024, 1, 3),
    );
    final List<MovieRenderEvent> events = await engine
        .renderMovie(
          request(<MovieClip>[
            clip(day1, frames: 45, keyframes: saved(45), chapterTitle: 'D1'),
            clip(day2, frames: 45, keyframes: saved(45), chapterTitle: 'D2'),
            clip(day3, frames: 30, keyframes: older(30), chapterTitle: 'D3'),
          ]),
        )
        .toList();

    final List<List<String>> steps = ffmpeg.executed;
    final String job = jobOf(steps);
    final List<String> concat = steps.last;
    final String listPath = concat[concat.indexOf('-i') + 1];
    expect(
      ffmpeg.textInputs[listPath],
      ConcatList.content(
        <String>[
          '$job/body-0.mp4',
          '$job/segment-0.mp4',
          '$job/body-1.mp4',
          day3.path,
        ],
        durations: <String>['1.166667', '0.400000', '1.166667', '1.000000'],
      ),
    );
    expect(
      steps[3],
      TransitionCommands.audio(
        inputs: <AudioInput>[
          (path: day1.path, seconds: '1.500000'),
          (path: day2.path, seconds: '1.500000'),
          (path: day3.path, seconds: '1.000000'),
        ],
        crossfades: const <bool>[true, false],
        output: '$job/audio.m4a',
        toAac: true,
        format: const ClipFormat.legacy(VideoOrientation.landscape),
      ),
    );
    const List<MovieChapter> chapters = <MovieChapter>[
      MovieChapter(startMs: 0, endMs: 1233, title: 'D1'),
      MovieChapter(startMs: 1233, endMs: 2733, title: 'D2'),
      MovieChapter(startMs: 2733, endMs: 3733, title: 'D3'),
    ];
    expect(
      ffmpeg.textInputs['$job/${FfmetadataChapters.fileName}'],
      FfmetadataChapters.encode(chapters),
    );
    expect(
      events.last,
      MovieCompleted(
        outputPath: movie,
        durationMs: 3733,
        chapters: chapters,
        transitions: 1,
        hardCuts: 1,
      ),
    );
  });

  // iOS allows 256 open files per process: the audio of more than 40 clips
  // goes in PCM chunks, joined by a last pass the same way.
  test('the audio of 41 clips is two PCM chunks then one AAC pass', () async {
    final List<MovieClip> clips = <MovieClip>[
      clip(day1, frames: 45, keyframes: saved(45)),
      for (int day = 2; day <= 41; day++)
        clip(
          await seedClip(
            paths,
            ProfileKey.defaultProfile,
            LocalDay(2024, 1, 1),
            ordinal: day,
          ),
          frames: 45,
          keyframes: saved(45),
        ),
    ];

    await engine.renderMovie(request(clips)).toList();

    final List<List<String>> steps = ffmpeg.executed;
    final String job = jobOf(steps);
    final List<List<String>> audio = steps
        .where((List<String> argv) => argv.contains('-filter_complex'))
        .where((List<String> argv) => !argv.contains('[v]'))
        .toList();
    expect(audio, hasLength(3));
    expect(audio[0].sublist(0, 2), <String>['-i', clips[0].path]);
    expect(audio[0].last, '-y');
    expect(audio[0][audio[0].length - 2], '$job/audio-0.wav');
    expect(audio[0].where((String a) => a == '-i'), hasLength(40));
    expect(audio[1].where((String a) => a == '-i'), hasLength(1));
    expect(
      audio[2],
      TransitionCommands.audio(
        inputs: <AudioInput>[
          // 40 clips of 1.5 s less 39 overlaps of 8 frames.
          (path: '$job/audio-0.wav', seconds: '49.600000'),
          (path: '$job/audio-1.wav', seconds: '1.500000'),
        ],
        crossfades: const <bool>[true],
        output: '$job/audio.m4a',
        toAac: true,
        format: const ClipFormat.legacy(VideoOrientation.landscape),
      ),
    );
  });

  test('progress: units of bodies, segments and audio, then the concat by '
      'time, never above 0.999', () async {
    // Each session takes a second, so no report is throttled away.
    ffmpeg.onExecute = (List<String> arguments) async {
      clock.advance(const Duration(seconds: 1));
      await ffmpeg.writeOutput(arguments);
    };
    ffmpeg.statistics = <FfmpegStatistics>[
      const FfmpegStatistics(
        timeMs: 1600,
        videoFrameNumber: 0,
        size: 0,
        speed: 1,
      ),
    ];

    final List<MovieRenderEvent> events = await engine
        .renderMovie(
          request(<MovieClip>[
            clip(day1, frames: 60, keyframes: saved(60)),
            clip(day2, frames: 45, keyframes: saved(45)),
          ]),
        )
        .toList();

    // 2 bodies + 1 segment (4) + 1 audio pass (2) + the concat (1) = 9.
    final List<double> fractions = <double>[
      for (final MovieRenderEvent event in events)
        if (event is MovieConcatenating) event.fraction,
    ];
    expect(fractions.first, closeTo(1 / 9, 1e-9));
    expect(fractions, isNot(contains(greaterThanOrEqualTo(1))));
    // The sample lands in the first clip's 1733 ms of 3233.
    expect(fractions.last, closeTo((8 + 1600 / 3233) / 9, 1e-9));
    expect(events.whereType<MovieConcatenating>().last.currentIndex, 0);
  });
}
