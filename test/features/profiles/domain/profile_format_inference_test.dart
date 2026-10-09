// What a profile found after a reinstall was made for, read off its newest
// clips' facts instead of landscape and legacy.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/profiles/domain/profile_format_inference.dart';

import '../../../shared/fakes/fake_profile_clip_facts.dart';

void main() {
  test('a portrait 4K HEVC 60 fps stereo clip gives portrait and that '
      'format; a landscape 1080p H.264 one gives landscape and legacy', () {
    final (
      :VideoOrientation orientation,
      :ClipFormat format,
    ) = ProfileFormatInference.infer(<ClipMeta>[
      clipFacts(
        width: 2160,
        height: 3840,
        codec: 'hevc',
        fps: 59.94,
        channels: 2,
      ),
    ]);

    expect(orientation, VideoOrientation.portrait);
    expect(format, ClipFormat.parse('2160p60-hevc-stereo-sdr', orientation));

    final (orientation: VideoOrientation shape, format: ClipFormat legacy) =
        ProfileFormatInference.infer(<ClipMeta>[clipFacts()]);
    expect(shape, VideoOrientation.landscape);
    expect(legacy, const ClipFormat.legacy(VideoOrientation.landscape));
    expect(legacy.isLegacy, isTrue);
  });

  test('the newest clip with facts decides; a clip marked v1.5 is legacy '
      'whatever its facts; HLG comes from the colour transfer; an unknown '
      'size, codec or channel count reads as the legacy value', () {
    final List<ClipMeta> facts = <ClipMeta>[
      const ClipMeta(subtitleText: 'no facts yet'),
      clipFacts(width: 1920, height: 1080, codec: 'hevc', channels: 2),
      clipFacts(width: 1080, height: 1920),
    ];
    expect(
      ProfileFormatInference.infer(facts).format,
      ClipFormat.parse('1080p30-hevc-stereo-sdr', VideoOrientation.landscape),
    );

    expect(
      ProfileFormatInference.inferFormat(<ClipMeta>[
        const ClipMeta(
          schema: ClipSchema.v15,
          width: 1920,
          height: 1080,
          codec: 'hevc',
          channels: 2,
        ),
      ], VideoOrientation.landscape),
      const ClipFormat.legacy(VideoOrientation.landscape),
    );

    expect(
      ProfileFormatInference.inferFormat(<ClipMeta>[
        clipFacts(
          width: 3840,
          height: 2160,
          codec: 'hevc',
          colorTransfer: 'arib-std-b67',
        ),
      ], VideoOrientation.landscape).range,
      DynamicRange.hlg,
    );
    // HLG is HEVC only: an H.264 clip tagged HLG never makes an invalid
    // format (`ClipFormat.isValid`).
    expect(
      ProfileFormatInference.inferFormat(<ClipMeta>[
        clipFacts(
          width: 1920,
          height: 1080,
          codec: 'h264',
          colorTransfer: 'arib-std-b67',
        ),
      ], VideoOrientation.landscape).range,
      DynamicRange.sdr,
    );

    final ClipFormat odd = ProfileFormatInference.inferFormat(<ClipMeta>[
      const ClipMeta(width: 1280, height: 960, codec: 'vp9', fps: 24),
    ], VideoOrientation.landscape);
    expect(odd.tier, ResolutionTier.p1080);
    expect(odd.codec, VideoCodec.h264);
    expect(odd.fps, FrameRate.f30);
    expect(odd.channels, AudioChannels.mono);
  });

  test('an imported video still in the folder (not ours) decides only '
      'when no clip of the app\'s own can', () {
    const ClipMeta foreign = ClipMeta(
      schema: ClipSchema.other,
      width: 2160,
      height: 3840,
      codec: 'hevc',
      fps: 59.94,
      channels: 2,
    );
    final ClipMeta own = clipFacts(); // 1920×1080 H.264 30 fps mono.

    final (:VideoOrientation orientation, :ClipFormat format) =
        ProfileFormatInference.infer(<ClipMeta>[foreign, own]);
    expect(orientation, VideoOrientation.landscape);
    expect(format, const ClipFormat.legacy(VideoOrientation.landscape));

    final (orientation: VideoOrientation alone, format: ClipFormat theirs) =
        ProfileFormatInference.infer(<ClipMeta>[foreign]);
    expect(alone, VideoOrientation.portrait);
    expect(theirs, ClipFormat.parse('2160p60-hevc-stereo-sdr', alone));
  });

  test('nothing to read gives landscape and legacy', () {
    final (:VideoOrientation orientation, :ClipFormat format) =
        ProfileFormatInference.infer(const <ClipMeta>[]);

    expect(orientation, VideoOrientation.landscape);
    expect(format, const ClipFormat.legacy(VideoOrientation.landscape));
  });
}
