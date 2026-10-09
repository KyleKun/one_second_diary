import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/commands/transition_commands.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

import '../../../support/track_1a/platform_layouts.dart';

const ClipFormat legacy = ClipFormat.legacy(VideoOrientation.landscape);
const FrameRate f30 = FrameRate.f30;

const List<VideoEncoder> h264Encoders = <VideoEncoder>[
  VideoEncoder.libx264,
  VideoEncoder.videoToolbox,
  VideoEncoder.mediaCodec,
];

/// The Ultra preset: 4K60 HEVC stereo.
const ClipFormat ultra = ClipFormat(
  tier: ResolutionTier.p2160,
  orientation: VideoOrientation.landscape,
  codec: VideoCodec.hevc,
  fps: FrameRate.f60,
  channels: AudioChannels.stereo,
  range: DynamicRange.sdr,
);

/// The argv of each legacy command on [layout], named.
List<(String, List<String>)> commands(Layout layout) {
  final String videos = layout.videos;
  final String job = '${layout.cache}/scratch/job-1';
  return <(String, List<String>)>[
    (
      'body of the first clip: no seek, cut before keyframe 50',
      TransitionCommands.body(
        input: '${videos}2026-09-01.mp4',
        output: '$job/body-0.mp4',
        headCut: 0,
        tailCut: 50,
        fps: f30,
      ),
    ),
    (
      'body of a middle clip: from keyframe 10, 25 frames',
      TransitionCommands.body(
        input: '${videos}Profiles/My Trip/2026-09-02.mp4',
        output: '$job/body-1.mp4',
        headCut: 10,
        tailCut: 35,
        fps: f30,
      ),
    ),
    (
      'body of the last clip: from keyframe 10 to the end',
      TransitionCommands.body(
        input: '${videos}2026-09-03.mp4',
        output: '$job/body-2.mp4',
        headCut: 10,
        tailCut: null,
        fps: f30,
      ),
    ),
    for (final VideoEncoder encoder in h264Encoders)
      (
        'segment ${encoder.name}: a 10-frame tail and a 10-frame head, '
            'crossfaded',
        TransitionCommands.segment(
          before: '${videos}2026-09-01.mp4',
          beforeFrameCount: 60,
          beforeTailCut: 50,
          after: '${videos}Profiles/My Trip/2026-09-02.mp4',
          afterHeadCut: 10,
          emptySubtitles: '$job/empty.srt',
          transition: MovieTransition.crossfade,
          format: legacy,
          encoder: encoder,
          output: '$job/segment-0.mp4',
        ),
      ),
    (
      'segment through black: a 12-frame VideoToolbox tail',
      TransitionCommands.segment(
        before: '${videos}2026-09-02.mp4',
        beforeFrameCount: 60,
        beforeTailCut: 48,
        after: '${videos}2026-09-03.mp4',
        afterHeadCut: 12,
        emptySubtitles: '$job/empty.srt',
        transition: MovieTransition.fadeBlack,
        format: legacy,
        encoder: VideoEncoder.videoToolbox,
        output: '$job/segment-1.mp4',
      ),
    ),
    (
      'audio of three clips, a crossfade then a hard cut, to AAC',
      TransitionCommands.audio(
        inputs: <AudioInput>[
          (path: '${videos}2026-09-01.mp4', seconds: '2.000000'),
          (
            path: '${videos}Profiles/My Trip/2026-09-02.mp4',
            seconds: '1.500000',
          ),
          (path: '${videos}2026-09-03.mp4', seconds: '1.000000'),
        ],
        crossfades: const <bool>[true, false],
        output: '$job/audio.m4a',
        toAac: true,
        format: legacy,
      ),
    ),
    (
      'audio chunk of two clips to PCM',
      TransitionCommands.audio(
        inputs: <AudioInput>[
          (path: '${videos}2026-09-01.mp4', seconds: '2.000000'),
          (path: '${videos}2026-09-02.mp4', seconds: '1.500000'),
        ],
        crossfades: const <bool>[true],
        output: '$job/audio-0.wav',
        toAac: false,
        format: legacy,
      ),
    ),
    (
      'audio of one clip (a chunk of one)',
      TransitionCommands.audio(
        inputs: <AudioInput>[
          (path: '${videos}2026-09-03.mp4', seconds: '1.000000'),
        ],
        crossfades: const <bool>[],
        output: '$job/audio-1.wav',
        toAac: false,
        format: legacy,
      ),
    ),
  ];
}

/// The frozen argv on Android, in the order of [commands].
List<List<String>> expectedOnAndroid() {
  final String videos = android.videos;
  final String job = '${android.cache}/scratch/job-1';
  const Map<VideoEncoder, List<String>> encoder = <VideoEncoder, List<String>>{
    VideoEncoder.libx264: <String>[
      '-c:v', 'libx264', '-crf', '20', '-preset', 'medium', //
    ],
    VideoEncoder.videoToolbox: <String>[
      '-c:v', 'h264_videotoolbox', '-b:v', '12000k', //
      '-profile:v', 'high', '-allow_sw', '1',
    ],
    VideoEncoder.mediaCodec: <String>[
      '-c:v', 'h264_mediacodec', '-b:v', '12000k', //
    ],
  };
  return <List<String>>[
    <String>[
      '-i', '${videos}2026-09-01.mp4', '-frames:v', '50', //
      '-map', '0:v', '-map', '0:s?', '-c', 'copy', '-an',
      '$job/body-0.mp4', '-y',
    ],
    <String>[
      '-ss', '0.333333', '-i', '${videos}Profiles/My Trip/2026-09-02.mp4', //
      '-frames:v', '25', '-map', '0:v', '-map', '0:s?', '-c', 'copy', '-an',
      '$job/body-1.mp4', '-y',
    ],
    <String>[
      '-ss', '0.333333', '-i', '${videos}2026-09-03.mp4', //
      '-map', '0:v', '-map', '0:s?', '-c', 'copy', '-an',
      '$job/body-2.mp4', '-y',
    ],
    for (final VideoEncoder h264 in h264Encoders)
      <String>[
        '-ss', '1.6666', '-i', '${videos}2026-09-01.mp4', //
        '-t', '0.333333', '-i', '${videos}Profiles/My Trip/2026-09-02.mp4',
        '-i', '$job/empty.srt',
        '-filter_complex',
        '[0:v][1:v]xfade=transition=fade:duration=0.266667:offset=0.066667[v]',
        '-map', '[v]', '-map', '2:s', '-c:s', 'mov_text',
        '-r', '30', ...encoder[h264]!, '-pix_fmt', 'yuv420p', '-an',
        '$job/segment-0.mp4', '-y',
      ],
    <String>[
      '-ss', '1.6000', '-i', '${videos}2026-09-02.mp4', //
      '-t', '0.400000', '-i', '${videos}2026-09-03.mp4',
      '-i', '$job/empty.srt',
      '-filter_complex',
      '[0:v][1:v]xfade=transition=fadeblack:duration=0.266667:'
          'offset=0.133333[v]',
      '-map', '[v]', '-map', '2:s', '-c:s', 'mov_text',
      '-r', '30', ...encoder[VideoEncoder.videoToolbox]!,
      '-pix_fmt', 'yuv420p', '-an', '$job/segment-1.mp4', '-y',
    ],
    <String>[
      '-i', '${videos}2026-09-01.mp4', //
      '-i', '${videos}Profiles/My Trip/2026-09-02.mp4',
      '-i', '${videos}2026-09-03.mp4',
      '-filter_complex',
      '[0:a]apad,atrim=0:2.000000[a0];'
          '[1:a]apad,atrim=0:1.500000[a1];'
          '[2:a]apad,atrim=0:1.000000[a2];'
          '[a0][a1]acrossfade=d=0.266667:c1=tri:c2=tri[x1];'
          '[x1][a2]concat=n=2:v=0:a=1[a]',
      '-map', '[a]', '-ac', '1', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
      '$job/audio.m4a', '-y',
    ],
    <String>[
      '-i', '${videos}2026-09-01.mp4', '-i', '${videos}2026-09-02.mp4', //
      '-filter_complex',
      '[0:a]apad,atrim=0:2.000000[a0];'
          '[1:a]apad,atrim=0:1.500000[a1];'
          '[a0][a1]acrossfade=d=0.266667:c1=tri:c2=tri[a]',
      '-map', '[a]', '-c:a', 'pcm_s16le', '$job/audio-0.wav', '-y',
    ],
    <String>[
      '-i', '${videos}2026-09-03.mp4', //
      '-filter_complex', '[0:a]apad,atrim=0:1.000000[a]',
      '-map', '[a]', '-c:a', 'pcm_s16le', '$job/audio-1.wav', '-y',
    ],
  ];
}

void main() {
  // A body is a stream copy from its head keyframe's exact time (none for 0) for
  // `tail - head` frames (none for the end), video and subtitles only; a segment decodes
  // the tail from its keyframe (rounded down) and the head for its frames, crossfades them
  // 8 frames before the tail's end, and encodes with the clips' own video settings plus
  // the empty subtitle stream; the audio pass trims every clip to its length and chains
  // acrossfade or concat per boundary, to AAC or to PCM for a chunk.
  test('every legacy command is the literal argv on Android', () {
    final List<(String, List<String>)> v3 = commands(android);
    final List<List<String>> frozen = expectedOnAndroid();
    expect(v3, hasLength(frozen.length));
    for (final (int i, (String name, List<String> argv)) in v3.indexed) {
      expect(argv, frozen[i], reason: name);
    }
  });

  test('iOS: the same elements as Android, every path whole', () {
    final List<List<String>> frozen = expectedOnAndroid();
    for (final (int i, (String name, List<String> argv)) in commands(
      ios,
    ).indexed) {
      expect(
        argv,
        onLayout(frozen[i], from: android, to: ios),
        reason: name,
      );
    }
  });

  // GOLDEN: at 60 fps the same times are twice the frames: a body from keyframe 20 is
  // still `-ss 0.333333`, a 16-frame transition is still 0.266667 s, the segment encodes
  // at `-r 60` with the HEVC encoder, pixel format and hvc1 tag, and the AAC track is stereo.
  test('the Ultra format: 60 fps bodies and segments, a stereo audio pass', () {
    final String videos = android.videos;
    final String job = '${android.cache}/scratch/job-1';
    expect(
      TransitionCommands.body(
        input: '${videos}2026-09-02.mp4',
        output: '$job/body-1.mp4',
        headCut: 20,
        tailCut: 70,
        fps: FrameRate.f60,
      ),
      <String>[
        '-ss', '0.333333', '-i', '${videos}2026-09-02.mp4', //
        '-frames:v', '50', '-map', '0:v', '-map', '0:s?', '-c', 'copy', '-an',
        '$job/body-1.mp4', '-y',
      ],
    );
    expect(
      TransitionCommands.segment(
        before: '${videos}2026-09-01.mp4',
        beforeFrameCount: 120,
        beforeTailCut: 100,
        after: '${videos}2026-09-02.mp4',
        afterHeadCut: 20,
        emptySubtitles: '$job/empty.srt',
        transition: MovieTransition.crossfade,
        format: ultra,
        encoder: VideoEncoder.hevcMediaCodec,
        output: '$job/segment-0.mp4',
      ),
      <String>[
        '-ss', '1.6666', '-i', '${videos}2026-09-01.mp4', //
        '-t', '0.333333', '-i', '${videos}2026-09-02.mp4',
        '-i', '$job/empty.srt',
        '-filter_complex',
        '[0:v][1:v]xfade=transition=fade:duration=0.266667:offset=0.066667[v]',
        '-map', '[v]', '-map', '2:s', '-c:s', 'mov_text',
        '-r', '60', '-c:v', 'hevc_mediacodec', '-b:v', '42000k',
        '-pix_fmt', 'yuv420p', '-tag:v', 'hvc1', '-an',
        '$job/segment-0.mp4', '-y',
      ],
    );
    expect(
      TransitionCommands.audio(
        inputs: <AudioInput>[
          (path: '${videos}2026-09-01.mp4', seconds: '2.000000'),
          (path: '${videos}2026-09-02.mp4', seconds: '1.500000'),
        ],
        crossfades: const <bool>[true],
        output: '$job/audio.m4a',
        toAac: true,
        format: ultra,
      ),
      <String>[
        '-i', '${videos}2026-09-01.mp4', '-i', '${videos}2026-09-02.mp4', //
        '-filter_complex',
        '[0:a]apad,atrim=0:2.000000[a0];'
            '[1:a]apad,atrim=0:1.500000[a1];'
            '[a0][a1]acrossfade=d=0.266667:c1=tri:c2=tri[a]',
        '-map',
        '[a]',
        '-ac',
        '2',
        '-ar',
        '48000',
        '-c:a',
        'aac',
        '-b:a',
        '256k',
        '$job/audio.m4a', '-y',
      ],
    );
  });

  test('the audio pass refuses no inputs or a boundary count that does not '
      'match', () {
    expect(
      () => TransitionCommands.audio(
        inputs: const <AudioInput>[],
        crossfades: const <bool>[],
        output: '/j/audio.m4a',
        toAac: true,
        format: legacy,
      ),
      throwsArgumentError,
    );
    expect(
      () => TransitionCommands.audio(
        inputs: const <AudioInput>[(path: '/v/a.mp4', seconds: '1.000000')],
        crossfades: const <bool>[true],
        output: '/j/audio.m4a',
        toAac: true,
        format: legacy,
      ),
      throwsArgumentError,
    );
  });
}
