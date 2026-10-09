import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/commands/concat_command.dart';
import 'package:one_second_diary/core/media/commands/music_commands.dart';
import 'package:one_second_diary/core/media/commands/transition_commands.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/policy/concat_list.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/movie_clip.dart';
import 'package:one_second_diary/core/media/types/movie_music.dart';
import 'package:one_second_diary/core/media/types/movie_render_event.dart';
import 'package:one_second_diary/core/media/types/movie_render_request.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../support/support.dart';
import '../../support/track_1a/media_engine_harness.dart';
import '../../support/track_1a/scripted_ffmpeg_gateway.dart';

/// A v1.5 clip on the landscape canvas, [frames] long, with [keyframes]
/// (null: unknown).
MovieClip clip(File file, {required int frames, ClipKeyframes? keyframes}) =>
    MovieClip(
      path: file.path,
      durationMs: (frames * 1000 / 30).round(),
      isOsdV15: true,
      hasAudio: true,
      hasSubtitleStream: false,
      width: 1920,
      height: 1080,
      codec: 'h264',
      fps: 30,
      channels: 1,
      pixelFormat: 'yuv420p',
      keyframes: keyframes,
    );

/// The keyframes of a clip saved with cut keyframes, [frames] long.
ClipKeyframes saved(int frames) =>
    ClipKeyframes(frameCount: frames, indices: <int>[0, 10, frames - 10]);

void main() {
  late AppPaths paths;
  late ScriptedFfmpegGateway ffmpeg;
  late MediaEngine engine;
  late File day1;
  late File day2;
  late String movie;
  late List<String> tracks;

  setUp(() async {
    paths = await createTestPaths();
    final FakeClock clock = FakeClock(DateTime(2024, 1, 5, 10));
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
    // The picker's copies, somewhere the engine's scratch sweep never is.
    final Directory music = await Directory(
      '${paths.cacheDir}/music-1',
    ).create(recursive: true);
    tracks = <String>[
      (await File('${music.path}/0-song.mp3').writeAsBytes(<int>[1])).path,
      (await File('${music.path}/1-b side.m4a').writeAsBytes(<int>[1])).path,
    ];
  });

  MovieRenderRequest request(
    List<MovieClip> clips, {
    required MovieMusic music,
    MovieTransition? transition,
  }) => MovieRenderRequest(
    clips: clips,
    format: const ClipFormat.legacy(VideoOrientation.landscape),
    outputPath: movie,
    title: 'January 2024',
    comment: 'profile=',
    description: 'clips=2;from=2024-01-01;to=2024-01-02;music=on',
    transition: transition,
    music: music,
  );

  /// The job folder of the first session's output.
  String jobOf(List<List<String>> executed) =>
      File(ScriptedFfmpegGateway.outputOf(executed.first)!).parent.path;

  // Without a transition the join is the concat of the clips as they are, but their audio
  // is made in one pass first (plain concat), the music joined, looped to the movie's
  // length and mixed over it, and the concat takes the mix as the first track and the
  // clips' own sound as the second. The request's description is written as it is.
  test('a movie with music and no transition: the clips\' audio pass, '
      'sequence, loop, mix, then the concat with both tracks', () async {
    final List<MovieRenderEvent> events = await engine
        .renderMovie(
          request(<MovieClip>[
            clip(day1, frames: 60),
            clip(day2, frames: 45),
          ], music: MovieMusic(tracks: tracks)),
        )
        .toList();

    expect(ffmpeg.probed, isEmpty);
    final List<List<String>> steps = ffmpeg.executed;
    final String job = jobOf(steps);
    final String listPath = steps.last[steps.last.indexOf('-i') + 1];
    expect(steps, <List<String>>[
      TransitionCommands.audio(
        inputs: <AudioInput>[
          (path: day1.path, seconds: '2.000000'),
          (path: day2.path, seconds: '1.500000'),
        ],
        crossfades: const <bool>[false],
        output: '$job/audio.m4a',
        toAac: true,
        format: const ClipFormat.legacy(VideoOrientation.landscape),
      ),
      MusicCommands.sequence(tracks: tracks, output: '$job/sequence.wav'),
      MusicCommands.loop(
        sequence: '$job/sequence.wav',
        durationMs: 3500,
        output: '$job/loop.wav',
      ),
      MusicCommands.mix(
        music: '$job/loop.wav',
        clips: '$job/audio.m4a',
        volume: MovieMusic.defaultVolume,
        durationMs: 3500,
        output: '$job/mix.m4a',
      ),
      ConcatCommand.build(
        listPath: listPath,
        outputPath: movie,
        title: 'January 2024',
        comment: 'profile=',
        description: 'clips=2;from=2024-01-01;to=2024-01-02;music=on',
        audioPath: '$job/mix.m4a',
        secondAudioPath: '$job/audio.m4a',
      ),
    ]);
    expect(
      ffmpeg.textInputs[listPath],
      ConcatList.content(<String>[day1.path, day2.path]),
    );
    expect(events.last, MovieCompleted(outputPath: movie, durationMs: 3500));
    expect(File(movie).existsSync(), isTrue);
    expect(Directory(paths.scratchDir).listSync(recursive: true), isEmpty);
  });

  // With a transition the one-pass audio already exists (crossfaded); the
  // music plays in place of it here (the clips' sound stays the second
  // track), at a volume of 0.8, over the movie's shorter length.
  test('a movie with music and a transition: the mix over the crossfaded '
      'pass, the music alone when the videos\' sound is off', () async {
    await engine
        .renderMovie(
          request(
            <MovieClip>[
              clip(day1, frames: 60, keyframes: saved(60)),
              clip(day2, frames: 45, keyframes: saved(45)),
            ],
            music: MovieMusic(
              tracks: <String>[tracks.first],
              volume: 0.8,
              keepClipSound: false,
            ),
            transition: MovieTransition.crossfade,
          ),
        )
        .toList();

    final List<List<String>> steps = ffmpeg.executed;
    final String job = jobOf(steps);
    expect(steps, hasLength(8));
    expect(
      steps[3],
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
    );
    expect(steps.sublist(4, 7), <List<String>>[
      MusicCommands.sequence(
        tracks: <String>[tracks.first],
        output: '$job/sequence.wav',
      ),
      MusicCommands.loop(
        sequence: '$job/sequence.wav',
        durationMs: 3233,
        output: '$job/loop.wav',
      ),
      MusicCommands.mix(
        music: '$job/loop.wav',
        clips: null,
        volume: 0.8,
        durationMs: 3233,
        output: '$job/mix.m4a',
      ),
    ]);
    final List<String> concat = steps.last;
    expect(
      concat,
      ConcatCommand.build(
        listPath: concat[concat.indexOf('-i') + 1],
        outputPath: movie,
        title: 'January 2024',
        comment: 'profile=',
        description:
            'clips=2;from=2024-01-01;to=2024-01-02;music=on;transition=fade',
        audioPath: '$job/mix.m4a',
        secondAudioPath: '$job/audio.m4a',
      ),
    );
  });

  test('a music file that is gone fails the movie before any session, '
      'naming it', () async {
    final String gone = '${paths.cacheDir}/music-1/gone.mp3';
    await expectLater(
      engine
          .renderMovie(
            request(<MovieClip>[
              clip(day1, frames: 60),
              clip(day2, frames: 45),
            ], music: MovieMusic(tracks: <String>[tracks.first, gone])),
          )
          .toList(),
      throwsA(
        isA<VideoProcessingException>().having(
          (VideoProcessingException e) => e.message,
          'message',
          contains(gone),
        ),
      ),
    );
    expect(ffmpeg.executed, isEmpty);
    expect(File(movie).existsSync(), isFalse);
  });
}
