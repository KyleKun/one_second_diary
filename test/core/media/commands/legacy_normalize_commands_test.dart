// The normalisation of a clip before a movie, steps A to F. The expected argvs are
// frozen: the temps sit next to the original and the placeholder SRT in the internal
// folder. For the legacy format libx264 takes `-preset medium`; other formats add the
// tier's canvas, `-r 60`, the output pixel format and hvc1 tag after the encoder, a
// stereo layout, and the `v2` marker in step F.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/commands/legacy_normalize_commands.dart';
import 'package:one_second_diary/core/media/commands/probe_commands.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

import '../../../support/track_1a/platform_layouts.dart';

const List<VideoEncoder> h264Encoders = <VideoEncoder>[
  VideoEncoder.libx264,
  VideoEncoder.videoToolbox,
  VideoEncoder.mediaCodec,
];

const ClipFormat ultra = ClipFormat(
  tier: ResolutionTier.p2160,
  orientation: VideoOrientation.landscape,
  codec: VideoCodec.hevc,
  fps: FrameRate.f60,
  channels: AudioChannels.stereo,
  range: DynamicRange.sdr,
);

/// Range conversions, letter for letter (also pinned in range_filter_test): an HDR
/// source into an SDR profile, an SDR source into an HLG one, a PQ source into an HLG one.
const String hdrToSdr =
    'zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,'
    'tonemap=hable,zscale=t=bt709:m=bt709:r=tv,format=yuv420p';
const String sdrToHlg =
    'zscale=pin=bt709:tin=bt709:min=bt709:t=linear:npl=100,'
    'format=gbrpf32le,exposure=exposure=-2.3,zscale=p=bt2020,'
    'zscale=t=arib-std-b67:m=bt2020nc:r=tv:npl=1000,format=yuv420p10le';
const String pqToHlg =
    'zscale=t=linear:npl=1000,format=gbrpf32le,'
    'zscale=t=arib-std-b67:m=bt2020nc:r=tv:npl=1000,format=yuv420p10le';

/// The HLG output settings: 10-bit p010le, the BT.2100 tags, hvc1.
const List<String> hlgOutput = <String>[
  '-pix_fmt', 'p010le', //
  '-color_primaries', 'bt2020', '-color_trc', 'arib-std-b67',
  '-colorspace', 'bt2020nc',
  '-tag:v', 'hvc1',
];

/// 1080p30 HEVC stereo HLG, landscape.
const ClipFormat hlg1080 = ClipFormat(
  tier: ResolutionTier.p1080,
  orientation: VideoOrientation.landscape,
  codec: VideoCodec.hevc,
  fps: FrameRate.f30,
  channels: AudioChannels.stereo,
  range: DynamicRange.hlg,
);

/// Every legacy step on [layout], labelled.
List<(String, List<String>)> steps(Layout layout) {
  final String original = '${layout.videos}Profiles/My Trip/2020-01-01.mp4';
  final String t1 = '${layout.videos}Profiles/My Trip/2020-01-01_42.mp4';
  final String t2 = '${layout.videos}Profiles/My Trip/2020-01-01_43.mp4';
  return <(String, List<String>)>[
    for (final VideoOrientation orientation in VideoOrientation.values)
      for (final VideoEncoder encoder in h264Encoders)
        (
          'A ${orientation.name} ${encoder.name}',
          LegacyNormalizeCommands.canvas(
            source: original,
            output: t1,
            format: ClipFormat.legacy(orientation),
            encoder: encoder,
          ),
        ),
    ('B', ProbeCommands.streams(t1)),
    (
      'C',
      LegacyNormalizeCommands.audio(
        input: t1,
        output: t2,
        format: const ClipFormat.legacy(VideoOrientation.landscape),
      ),
    ),
    (
      'D',
      LegacyNormalizeCommands.silentAudio(
        input: t1,
        output: t2,
        durationMs: 1533,
        format: const ClipFormat.legacy(VideoOrientation.landscape),
      ),
    ),
    (
      'E',
      LegacyNormalizeCommands.emptySubtitles(
        input: t1,
        subtitles: '${layout.internal}/subtitles.srt',
        output: t2,
      ),
    ),
    (
      'F',
      LegacyNormalizeCommands.tags(
        input: t1,
        output: t2,
        format: const ClipFormat.legacy(VideoOrientation.landscape),
      ),
    ),
  ];
}

/// The frozen argv for each step of [steps] on Android.
List<(String, List<String>)> v17OnAndroid() {
  const String original =
      '/storage/emulated/0/DCIM/OneSecondDiary/Profiles/My Trip/2020-01-01.mp4';
  const String t1 =
      '/storage/emulated/0/DCIM/OneSecondDiary/Profiles/My Trip/'
      '2020-01-01_42.mp4';
  const String t2 =
      '/storage/emulated/0/DCIM/OneSecondDiary/Profiles/My Trip/'
      '2020-01-01_43.mp4';
  const Map<VideoOrientation, String> canvas = <VideoOrientation, String>{
    VideoOrientation.landscape:
        'scale=1920:1080:force_original_aspect_ratio=decrease,'
        'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black',
    VideoOrientation.portrait:
        'scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920',
  };
  const Map<VideoEncoder, List<String>> encoder = <VideoEncoder, List<String>>{
    VideoEncoder.libx264: <String>[
      '-c:v', 'libx264', '-crf', '20', '-preset', 'medium', //
    ],
    VideoEncoder.videoToolbox: <String>[
      '-c:v', 'h264_videotoolbox', '-b:v', '12000k', //
      '-profile:v', 'high', '-allow_sw', '1',
    ],
    VideoEncoder.mediaCodec: <String>[
      '-c:v',
      'h264_mediacodec',
      '-b:v',
      '12000k',
    ],
  };
  return <(String, List<String>)>[
    // A: re-encode to the canvas at 30 fps, copying audio and subtitles.
    for (final VideoOrientation orientation in VideoOrientation.values)
      for (final VideoEncoder h264 in h264Encoders)
        (
          'A ${orientation.name} ${h264.name}',
          <String>[
            '-i', original, '-vf', canvas[orientation]!, //
            '-r', '30', '-map', '0', ...encoder[h264]!,
            '-c:a', 'copy', '-c:s', 'copy', t1, '-y',
          ],
        ),
    // B: the stream inventory (ffprobe) with `-show_chapters`; nothing is read from it here.
    (
      'B',
      <String>[
        '-v', 'quiet', '-print_format', 'json', //
        '-show_format', '-show_streams', '-show_chapters', t1,
      ],
    ),
    // C: mono 48 kHz AAC 256k, video and subtitles copied.
    (
      'C',
      <String>[
        '-i', t1, '-map', '0', '-c:v', 'copy', '-c:a', 'aac', //
        '-ac', '1', '-ar', '48000', '-b:a', '256k', '-c:s', 'copy', t2, '-y',
      ],
    ),
    // D: add a silent mono track the length of the clip. The silence is cut with -t (in
    // seconds), because -shortest also stops at the 1 ms placeholder subtitle and leaves
    // a clip without video.
    (
      'D',
      <String>[
        '-i', t1, '-f', 'lavfi', '-t', '1533ms', //
        '-i', 'anullsrc=channel_layout=mono:sample_rate=48000',
        '-map', '0', '-map', '1:a',
        '-b:a', '256k', '-c:v', 'copy', '-c:s', 'copy', '-c:a', 'aac', t2, '-y',
      ],
    ),
    // E: add an empty mov_text stream from the placeholder SRT.
    (
      'E',
      <String>[
        '-i', t1, //
        '-i',
        '/data/user/0/com.kylekun.one_second_diary/app_flutter/subtitles.srt',
        '-c', 'copy', '-c:s', 'mov_text', t2, '-y',
      ],
    ),
    // F: tag the copy as a normalised old recording. The album is "Default"
    // even in other profiles: only the temporary copy carries these tags.
    (
      'F',
      <String>[
        '-i', t1, //
        '-metadata', 'artist=One Second Diary (v1.5)',
        '-metadata', 'album=Default',
        '-metadata', 'comment=origin=osd_recording_old',
        '-c:v', 'copy', '-c:a', 'copy', '-c:s', 'copy', t2, '-y',
      ],
    ),
  ];
}

void main() {
  test('every legacy step is v1.7\'s argv on Android, but for libx264\'s '
      'preset medium (D29)', () {
    final List<(String, List<String>)> v3 = steps(android);
    final List<(String, List<String>)> v17 = v17OnAndroid();
    expect(v3.map(((String, List<String>) s) => s.$1), <String>[
      for (final (String step, _) in v17) step,
    ]);
    for (final (int i, (String step, List<String> argv)) in v3.indexed) {
      expect(argv, v17[i].$2, reason: step);
    }
  });

  // With the clip's length (known after the probe) step A adds the save's
  // `-force_key_frames` pair right after the encoder's arguments, so the copy can be cut
  // for a transition.
  test('step A with a duration: the D27 keyframes after the encoder', () {
    final List<String> argv = LegacyNormalizeCommands.canvas(
      source: '${android.videos}2020-01-01.mp4',
      output: '${android.cache}/t1.mp4',
      format: const ClipFormat.legacy(VideoOrientation.landscape),
      encoder: VideoEncoder.libx264,
      durationMs: 1500,
    );
    expect(argv, <String>[
      '-i', '${android.videos}2020-01-01.mp4', //
      '-vf',
      'scale=1920:1080:force_original_aspect_ratio=decrease,'
          'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black',
      '-r', '30', '-map', '0', '-c:v', 'libx264', '-crf', '20',
      '-preset', 'medium', '-force_key_frames', '0.3333,1.1666',
      '-c:a', 'copy', '-c:s', 'copy', '${android.cache}/t1.mp4', '-y',
    ]);
  });

  // GOLDEN: a 4K60 HEVC stereo movie (the Ultra preset) normalises into its own canvas
  // and rate, with the output pixel format and hvc1 tag after the encoder, a stereo track,
  // keyframes 20 frames (333 ms) from each end, and the `v2` marker.
  test('the Ultra format: 4K canvas, -r 60, hvc1, stereo, the v2 marker', () {
    final String src = '${android.videos}2020-01-01.mp4';
    final String t1 = '${android.cache}/t1.mp4';
    final String t2 = '${android.cache}/t2.mp4';
    expect(
      LegacyNormalizeCommands.canvas(
        source: src,
        output: t1,
        format: ultra,
        encoder: VideoEncoder.hevcMediaCodec,
        durationMs: 2000,
      ),
      <String>[
        '-i', src, //
        '-vf',
        'scale=3840:2160:force_original_aspect_ratio=decrease,'
            'pad=3840:2160:(ow-iw)/2:(oh-ih)/2:black',
        '-r', '60', '-map', '0',
        '-c:v', 'hevc_mediacodec', '-b:v', '42000k',
        '-pix_fmt', 'yuv420p', '-tag:v', 'hvc1',
        '-force_key_frames', '0.3333,1.6666',
        '-c:a', 'copy', '-c:s', 'copy', t1, '-y',
      ],
    );
    expect(
      LegacyNormalizeCommands.audio(input: t1, output: t2, format: ultra),
      <String>[
        '-i', t1, '-map', '0', '-c:v', 'copy', '-c:a', 'aac', //
        '-ac', '2', '-ar', '48000', '-b:a', '256k', '-c:s', 'copy', t2, '-y',
      ],
    );
    expect(
      LegacyNormalizeCommands.silentAudio(
        input: t1,
        output: t2,
        durationMs: 2000,
        format: ultra,
      ),
      <String>[
        '-i', t1, '-f', 'lavfi', '-t', '2000ms', //
        '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
        '-map', '0', '-map', '1:a',
        '-b:a', '256k', '-c:v', 'copy', '-c:s', 'copy', '-c:a', 'aac', t2, '-y',
      ],
    );
    expect(
      LegacyNormalizeCommands.tags(input: t1, output: t2, format: ultra),
      <String>[
        '-i', t1, //
        '-metadata', 'artist=One Second Diary (v2)',
        '-metadata', 'album=Default',
        '-metadata', 'comment=origin=osd_recording_old',
        '-c:v', 'copy', '-c:a', 'copy', '-c:s', 'copy', t2, '-y',
      ],
    );
  });

  // iOS has Android's elements with the folders swapped, so every path is
  // one element, the space in "Application Support" included.
  test('iOS: the same elements as Android, every path whole', () {
    final List<(String, List<String>)> v17 = v17OnAndroid();
    for (final (int i, (String step, List<String> argv)) in steps(
      ios,
    ).indexed) {
      expect(
        argv,
        onLayout(v17[i].$2, from: android, to: ios),
        reason: step,
      );
    }
  });

  // HDR GOLDEN: only step A changes with the range. The clip's probed transfer decides
  // the conversion in front of the canvas (`RangeFilter`); steps C to F are the format's.
  test('step A: an HLG clip into an HLG movie keeps its range (Main10 on '
      'p010le, the BT.2100 tags); an HDR clip into a legacy movie is '
      'tone-mapped, the chain ending in yuv420p (review A, P2); an SDR clip '
      'into an HLG movie is raised; an SDR-tagged clip changes nothing', () {
    final String original = '${ios.videos}Profiles/My Trip/2020-01-01.mp4';
    final String t1 = '${ios.videos}Profiles/My Trip/2020-01-01_42.mp4';
    expect(
      LegacyNormalizeCommands.canvas(
        source: original,
        output: t1,
        format: hlg1080,
        encoder: VideoEncoder.hevcVideoToolbox,
        durationMs: 1500,
        sourceColorTransfer: 'arib-std-b67',
      ),
      <String>[
        '-i', original, //
        '-vf',
        'scale=1920:1080:force_original_aspect_ratio=decrease,'
            'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black',
        '-r', '30',
        '-map', '0',
        '-c:v', 'hevc_videotoolbox', '-b:v', '9600k',
        '-profile:v', 'main10', '-allow_sw', '1',
        ...hlgOutput,
        '-force_key_frames', '0.3333,1.1666',
        '-c:a', 'copy',
        '-c:s', 'copy',
        t1, '-y',
      ],
    );
    final String android1 = '${android.videos}Profiles/My Trip/2020-01-01.mp4';
    final String androidT1 =
        '${android.videos}Profiles/My Trip/2020-01-01_42.mp4';
    expect(
      LegacyNormalizeCommands.canvas(
        source: android1,
        output: androidT1,
        format: const ClipFormat.legacy(VideoOrientation.landscape),
        encoder: VideoEncoder.libx264,
        sourceColorTransfer: 'arib-std-b67',
      ),
      <String>[
        '-i', android1, //
        '-vf',
        '$hdrToSdr,'
            'scale=1920:1080:force_original_aspect_ratio=decrease,'
            'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black',
        '-r', '30',
        '-map', '0',
        '-c:v', 'libx264', '-crf', '20', '-preset', 'medium',
        '-c:a', 'copy',
        '-c:s', 'copy',
        androidT1, '-y',
      ],
      reason:
          'the legacy argv names no pixel format: the chain ends in '
          'yuv420p so libx264 never writes High 10',
    );
    expect(
      LegacyNormalizeCommands.canvas(
        source: android1,
        output: androidT1,
        format: hlg1080.withOrientation(VideoOrientation.portrait),
        encoder: VideoEncoder.hevcMediaCodec,
        durationMs: 1500,
        sourceColorTransfer: null,
      ),
      <String>[
        '-i', android1, //
        '-vf',
        '$sdrToHlg,'
            'scale=1080:1920:force_original_aspect_ratio=increase,'
            'crop=1080:1920',
        '-r', '30',
        '-map', '0',
        '-c:v', 'hevc_mediacodec', '-b:v', '9600k', '-profile:v', 'main10',
        ...hlgOutput,
        '-force_key_frames', '0.3333,1.1666',
        '-c:a', 'copy',
        '-c:s', 'copy',
        androidT1, '-y',
      ],
    );
    expect(
      LegacyNormalizeCommands.canvas(
        source: android1,
        output: androidT1,
        format: const ClipFormat.legacy(VideoOrientation.landscape),
        encoder: VideoEncoder.libx264,
        sourceColorTransfer: 'bt709',
      ),
      LegacyNormalizeCommands.canvas(
        source: android1,
        output: androidT1,
        format: const ClipFormat.legacy(VideoOrientation.landscape),
        encoder: VideoEncoder.libx264,
      ),
    );
  });
}
