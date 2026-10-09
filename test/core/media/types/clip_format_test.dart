import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

const ClipFormat _ultraHlg = ClipFormat(
  tier: ResolutionTier.p2160,
  orientation: VideoOrientation.portrait,
  codec: VideoCodec.hevc,
  fps: FrameRate.f60,
  channels: AudioChannels.stereo,
  range: DynamicRange.hlg,
);

void main() {
  // GOLDEN: the stored form of a profile's format (`clipFormat_<key>`).
  // Changing a token changes what every install reads back.
  test('toString is the canonical string, without the orientation, and '
      'parse reads it back on the given canvas', () {
    const Map<String, ClipFormat> rows = <String, ClipFormat>{
      '1080p30-h264-mono-sdr': ClipFormat.legacy(VideoOrientation.landscape),
      '2160p60-hevc-stereo-hlg': _ultraHlg,
      '720p30-h264-mono-sdr': ClipFormat(
        tier: ResolutionTier.p720,
        orientation: VideoOrientation.landscape,
        codec: VideoCodec.h264,
        fps: FrameRate.f30,
        channels: AudioChannels.mono,
        range: DynamicRange.sdr,
      ),
      '1440p30-hevc-stereo-sdr': ClipFormat(
        tier: ResolutionTier.p1440,
        orientation: VideoOrientation.landscape,
        codec: VideoCodec.hevc,
        fps: FrameRate.f30,
        channels: AudioChannels.stereo,
        range: DynamicRange.sdr,
      ),
    };
    for (final MapEntry<String, ClipFormat> row in rows.entries) {
      expect(row.value.toString(), row.key);
      expect(ClipFormat.parse(row.key, row.value.orientation), row.value);
    }
    expect(
      ClipFormat.parse('2160p60-hevc-stereo-hlg', VideoOrientation.landscape),
      _ultraHlg.withOrientation(VideoOrientation.landscape),
    );
  });

  test('parse never guesses: anything that is not exactly a canonical '
      'string is null', () {
    for (final String? stored in <String?>[
      null,
      '',
      'legacy',
      '1080p',
      '1080p30',
      '1080p30-h264-mono',
      '1080p30-h264-mono-sdr-extra',
      '1080P30-h264-mono-sdr',
      '1080p30-H264-mono-sdr',
      '1080p120-h264-mono-sdr',
      '4k60-hevc-stereo-sdr',
      '1080p30-av1-mono-sdr',
      '1080p30-h264-5.1-sdr',
      '1080p30-h264-mono-pq',
      // H.264 carries no HLG: a valid-looking string of an invalid format reads as absent too.
      '1080p30-h264-mono-hlg',
      '2160p60-h264-stereo-hlg',
      ' 1080p30-h264-mono-sdr',
      '1080p30-h264-mono-sdr\n',
    ]) {
      expect(
        ClipFormat.parse(stored, VideoOrientation.landscape),
        isNull,
        reason: '$stored',
      );
    }
  });

  test('legacy is 1080p H.264 30 fps mono SDR, the only format isLegacy', () {
    const ClipFormat legacy = ClipFormat.legacy(VideoOrientation.portrait);

    expect(legacy.isLegacy, isTrue);
    expect(legacy.orientation, VideoOrientation.portrait);
    expect((legacy.fpsValue, legacy.channelCount), (30, 1));
    expect(
      ClipFormatPreset.standard.format(VideoOrientation.landscape),
      const ClipFormat.legacy(VideoOrientation.landscape),
    );
    for (final ClipFormat other in <ClipFormat>[
      _ultraHlg,
      ClipFormatPreset.smallerFiles.format(VideoOrientation.landscape),
      legacy.copyWithTier(ResolutionTier.p720),
    ]) {
      expect(other.isLegacy, isFalse, reason: '$other');
    }
  });

  // GOLDEN: the canvas table.
  test('the canvas is the tier on its side: width × height per tier and '
      'orientation', () {
    const List<(ResolutionTier, int, int)> rows = <(ResolutionTier, int, int)>[
      (ResolutionTier.p720, 1280, 720),
      (ResolutionTier.p1080, 1920, 1080),
      (ResolutionTier.p1440, 2560, 1440),
      (ResolutionTier.p2160, 3840, 2160),
    ];
    for (final (ResolutionTier tier, int long, int short) in rows) {
      final ClipFormat landscape = _ultraHlg
          .withOrientation(VideoOrientation.landscape)
          .copyWithTier(tier);
      final ClipFormat portrait = landscape.withOrientation(
        VideoOrientation.portrait,
      );
      expect(
        (landscape.width, landscape.height),
        (long, short),
        reason: '$tier',
      );
      expect((portrait.width, portrait.height), (short, long), reason: '$tier');
      expect((landscape.shortSide, landscape.longSide), (short, long));
      expect((portrait.shortSide, portrait.longSide), (short, long));
    }
  });

  // GOLDEN: the four presets, always SDR.
  test('the presets are Standard 1080p30 H.264 mono, Smaller files 1080p30 '
      'HEVC stereo, High 1440p30 HEVC stereo, Ultra 2160p60 HEVC stereo', () {
    expect(
      <String>[
        for (final ClipFormatPreset preset in ClipFormatPreset.values)
          preset.format(VideoOrientation.landscape).toString(),
      ],
      <String>[
        '1080p30-h264-mono-sdr',
        '1080p30-hevc-stereo-sdr',
        '1440p30-hevc-stereo-sdr',
        '2160p60-hevc-stereo-sdr',
      ],
    );
    for (final ClipFormatPreset preset in ClipFormatPreset.values) {
      final ClipFormat portrait = preset.format(VideoOrientation.portrait);
      expect(portrait.orientation, VideoOrientation.portrait);
      expect(ClipFormatPreset.of(portrait), preset);
    }
    expect(ClipFormatPreset.of(_ultraHlg), isNull, reason: 'HDR is Advanced');
  });

  hdrTests();

  test('the enum tokens are what ffprobe and ffmpeg name them', () {
    expect(VideoCodec.h264.token, 'h264');
    expect(VideoCodec.hevc.token, 'hevc');
    expect(AudioChannels.mono.token, 'mono');
    expect(AudioChannels.stereo.token, 'stereo');
    expect(FrameRate.f60.value, 60);
    expect(AudioChannels.stereo.count, 2);
  });
}

void hdrTests() {
  test('isValid refuses H.264 with HLG alone; isHdr is the HLG range', () {
    const ClipFormat h264Hlg = ClipFormat(
      tier: ResolutionTier.p1080,
      orientation: VideoOrientation.landscape,
      codec: VideoCodec.h264,
      fps: FrameRate.f30,
      channels: AudioChannels.mono,
      range: DynamicRange.hlg,
    );
    expect(h264Hlg.isValid, isFalse);
    expect(_ultraHlg.isValid, isTrue);
    expect(const ClipFormat.legacy(VideoOrientation.landscape).isValid, isTrue);
    expect(_ultraHlg.isHdr, isTrue);
    expect(
      ClipFormatPreset.ultra.format(VideoOrientation.landscape).isHdr,
      isFalse,
    );
    expect(
      ClipFormat.parse('2160p60-hevc-stereo-hlg', VideoOrientation.portrait),
      _ultraHlg,
    );
  });
}

extension on ClipFormat {
  ClipFormat copyWithTier(ResolutionTier tier) => ClipFormat(
    tier: tier,
    orientation: orientation,
    codec: codec,
    fps: fps,
    channels: channels,
    range: range,
  );
}
