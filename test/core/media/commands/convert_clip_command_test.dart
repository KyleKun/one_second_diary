import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/commands/convert_clip_command.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

import '../../../support/track_1a/platform_layouts.dart';

const ClipFormat ultra = ClipFormat(
  tier: ResolutionTier.p2160,
  orientation: VideoOrientation.landscape,
  codec: VideoCodec.hevc,
  fps: FrameRate.f60,
  channels: AudioChannels.stereo,
  range: DynamicRange.sdr,
);

const ClipFormat smallerFilesPortrait = ClipFormat(
  tier: ResolutionTier.p1080,
  orientation: VideoOrientation.portrait,
  codec: VideoCodec.hevc,
  fps: FrameRate.f30,
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

void main() {
  // GOLDEN: a finished day clip scaled to the new canvas (pad or cover by orientation,
  // the burned stamp scales along), every stream kept, the video at the format's rate
  // with its encoder, pixel format and hvc1 tag, the save's keyframes, the audio
  // re-encoded into the format's layout when it differs, subtitles copied, tags copied
  // with the artist (the v2 marker) and the album rewritten.
  test(
    'a legacy clip into the Ultra preset: 4K canvas, -r 60, HEVC hvc1, '
    'audio re-encoded to stereo, tags copied, artist and album rewritten',
    () {
      for (final Layout layout in <Layout>[android, ios]) {
        final String source = '${layout.videos}Profiles/My Trip/2026-09-28.mp4';
        final String output = '${layout.cache}/scratch/out 1/2026-09-28.mp4';
        expect(
          ConvertClipCommand.build(
            source: source,
            output: output,
            format: ultra,
            encoder: VideoEncoder.hevcMediaCodec,
            albumLabel: 'My Trip 4K',
            durationMs: 1500,
            sourceChannels: 1,
          ),
          <String>[
            '-i', source, //
            '-map_metadata', '0',
            '-metadata', 'artist=One Second Diary (v2)',
            '-metadata', 'album=My Trip 4K',
            '-vf',
            'scale=3840:2160:force_original_aspect_ratio=decrease,'
                'pad=3840:2160:(ow-iw)/2:(oh-ih)/2:black',
            '-map', '0',
            '-r', '60',
            '-c:v', 'hevc_mediacodec', '-b:v', '42000k',
            '-pix_fmt', 'yuv420p', '-tag:v', 'hvc1',
            '-force_key_frames', '0.3333,1.1666',
            '-ac', '2', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
            '-c:s', 'copy',
            output, '-y',
          ],
          reason: layout.name,
        );
      }
    },
  );

  test('the audio is copied when the layout already matches; an unknown '
      'layout is re-encoded', () {
    const String source = '/v/2026-09-28.mp4';
    const String output = '/c/out/2026-09-28.mp4';
    expect(
      ConvertClipCommand.build(
        source: source,
        output: output,
        format: smallerFilesPortrait,
        encoder: VideoEncoder.hevcVideoToolbox,
        albumLabel: 'Default',
        durationMs: 3000,
        sourceChannels: 2,
      ),
      <String>[
        '-i', source, //
        '-map_metadata', '0',
        '-metadata', 'artist=One Second Diary (v2)',
        '-metadata', 'album=Default',
        '-vf',
        'scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920',
        '-map', '0',
        '-r', '30',
        '-c:v', 'hevc_videotoolbox', '-b:v', '8000k',
        '-profile:v', 'main', '-allow_sw', '1',
        '-pix_fmt', 'yuv420p', '-tag:v', 'hvc1',
        '-force_key_frames', '0.3333,2.6666',
        '-c:a', 'copy',
        '-c:s', 'copy',
        output, '-y',
      ],
    );
    final List<String> unknown = ConvertClipCommand.build(
      source: source,
      output: output,
      format: smallerFilesPortrait,
      encoder: VideoEncoder.hevcVideoToolbox,
      albumLabel: 'Default',
      durationMs: 3000,
      sourceChannels: null,
    );
    expect(
      unknown.sublist(unknown.indexOf('-ac'), unknown.indexOf('-c:s')),
      <String>['-ac', '2', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k'],
    );
    expect(
      unknown.where((String argument) => argument == 'copy'),
      hasLength(1),
      reason: 'the subtitles alone are copied',
    );
  });

  // Converting back into the legacy format (a 4K profile copied into a
  // Standard one) writes the v1.5 marker, libx264 at preset medium and
  // mono.
  test('into the legacy format: the v1.5 marker, libx264, mono', () {
    expect(
      ConvertClipCommand.build(
        source: '/v/2026-09-28.mp4',
        output: '/c/out/2026-09-28.mp4',
        format: const ClipFormat.legacy(VideoOrientation.landscape),
        encoder: VideoEncoder.libx264,
        albumLabel: 'Default',
        durationMs: 2000,
        sourceChannels: 2,
      ),
      <String>[
        '-i', '/v/2026-09-28.mp4', //
        '-map_metadata', '0',
        '-metadata', 'artist=One Second Diary (v1.5)',
        '-metadata', 'album=Default',
        '-vf',
        'scale=1920:1080:force_original_aspect_ratio=decrease,'
            'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black',
        '-map', '0',
        '-r', '30',
        '-c:v', 'libx264', '-crf', '20', '-preset', 'medium',
        '-pix_fmt', 'yuv420p',
        '-force_key_frames', '0.3333,1.6666',
        '-ac', '1', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-c:s', 'copy',
        '/c/out/2026-09-28.mp4', '-y',
      ],
    );
  });

  // HDR GOLDEN: the sidecar's transfer decides the conversion in front of the canvas
  // (`RangeFilter`): SDR into an HLG profile is raised (Main10 on p010le, BT.2100 tags,
  // HLG bitrate); HLG into an SDR profile is tone-mapped.
  test('into an HLG profile: the SDR-to-HLG chain, Main10, the BT.2100 '
      'tags; an HLG clip into the Ultra preset: the tone map, SDR HEVC', () {
    const String source = '/v/2026-09-28.mp4';
    const String output = '/c/out/2026-09-28.mp4';
    expect(
      ConvertClipCommand.build(
        source: source,
        output: output,
        format: hlg1080,
        encoder: VideoEncoder.hevcVideoToolbox,
        albumLabel: 'My Trip HDR',
        durationMs: 1500,
        sourceChannels: 1,
      ),
      <String>[
        '-i', source, //
        '-map_metadata', '0',
        '-metadata', 'artist=One Second Diary (v2)',
        '-metadata', 'album=My Trip HDR',
        '-vf',
        '$sdrToHlg,'
            'scale=1920:1080:force_original_aspect_ratio=decrease,'
            'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black',
        '-map', '0',
        '-r', '30',
        '-c:v', 'hevc_videotoolbox', '-b:v', '9600k',
        '-profile:v', 'main10', '-allow_sw', '1',
        ...hlgOutput,
        '-force_key_frames', '0.3333,1.1666',
        '-ac', '2', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-c:s', 'copy',
        output, '-y',
      ],
    );
    expect(
      ConvertClipCommand.build(
        source: source,
        output: output,
        format: ultra,
        encoder: VideoEncoder.hevcMediaCodec,
        albumLabel: 'My Trip 4K',
        durationMs: 3000,
        sourceChannels: 2,
        sourceColorTransfer: 'arib-std-b67',
      ),
      <String>[
        '-i', source, //
        '-map_metadata', '0',
        '-metadata', 'artist=One Second Diary (v2)',
        '-metadata', 'album=My Trip 4K',
        '-vf',
        '$hdrToSdr,'
            'scale=3840:2160:force_original_aspect_ratio=decrease,'
            'pad=3840:2160:(ow-iw)/2:(oh-ih)/2:black',
        '-map', '0',
        '-r', '60',
        '-c:v', 'hevc_mediacodec', '-b:v', '42000k',
        '-pix_fmt', 'yuv420p', '-tag:v', 'hvc1',
        '-force_key_frames', '0.3333,2.6666',
        '-c:a', 'copy',
        '-c:s', 'copy',
        output, '-y',
      ],
    );
  });
}
