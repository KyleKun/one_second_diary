// The recommendation: one test per rule, the five
// fixtures, and what the picker shows per format.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/encoder_policy.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';
import 'package:one_second_diary/features/profiles/domain/quality_recommender.dart';
import 'package:one_second_diary/features/profiles/domain/quality_rules.dart';

import '../../../shared/fakes/fake_camera_capability_probe.dart';

ClipFormat f(
  ResolutionTier tier,
  VideoCodec codec,
  FrameRate fps, {
  AudioChannels channels = AudioChannels.mono,
  VideoOrientation orientation = VideoOrientation.landscape,
}) => ClipFormat(
  tier: tier,
  orientation: orientation,
  codec: codec,
  fps: fps,
  channels: channels,
  range: DynamicRange.sdr,
);

const ResolutionTier p1080 = ResolutionTier.p1080;
const ResolutionTier p1440 = ResolutionTier.p1440;
const ResolutionTier p2160 = ResolutionTier.p2160;
const VideoCodec h264 = VideoCodec.h264;
const VideoCodec hevc = VideoCodec.hevc;
const FrameRate f30 = FrameRate.f30;
const FrameRate f60 = FrameRate.f60;
const int gb = 1000 * 1000 * 1000;

EncodeResult ok(double factor) =>
    EncodeResult(ok: true, realtimeFactor: factor);

/// The escalation on a phone that does everything.
final Map<ClipFormat, EncodeResult> flagshipEncode = <ClipFormat, EncodeResult>{
  f(p1080, h264, f30): ok(3.0),
  f(p1080, hevc, f30): ok(2.8),
  f(p1080, hevc, f60): ok(2.0),
  f(p1440, hevc, f30): ok(1.8),
  f(p2160, hevc, f30): ok(1.5),
  f(p2160, hevc, f60): ok(1.2),
  f(p2160, h264, f60): ok(0.8),
};

DeviceMediaProfile profileOf({
  required Map<ClipFormat, EncodeResult> encode,
  CameraCapability? camera = FakeCameraCapabilityProbe.flagship,
  int? freeBytes = 480 * gb,
}) => DeviceMediaProfile(
  checkedAt: DateTime(2026, 10, 7),
  appVersion: '2.1.0',
  deviceModel: 'test',
  encode: <String, EncodeResult>{
    for (final MapEntry<ClipFormat, EncodeResult> entry in encode.entries)
      entry.key.toString(): entry.value,
  },
  camera: camera,
  freeBytes: freeBytes,
);

QualityRecommendation recommend(
  DeviceMediaProfile? profile, {
  bool isIOS = false,
  VideoOrientation orientation = VideoOrientation.landscape,
}) => QualityRecommender.recommend(
  profile: profile,
  orientation: orientation,
  isIOS: isIOS,
);

void main() {
  group('rules', () {
    test('1: the tier is capped at the camera\'s (1440p allowed under a 4K '
        'camera) and the frame rate at the camera\'s', () {
      final DeviceMediaProfile camera1080 = profileOf(
        encode: flagshipEncode,
        camera: const CameraCapability(
          maxTier: p1080,
          fps60: true,
          channels: 2,
        ),
      );
      expect(
        recommend(camera1080).pick,
        f(p1080, hevc, f60, channels: AudioChannels.stereo),
      );

      final DeviceMediaProfile no60 = profileOf(
        encode: flagshipEncode,
        camera: const CameraCapability(
          maxTier: p2160,
          fps60: false,
          channels: 2,
        ),
      );
      expect(
        recommend(no60).pick,
        f(p2160, hevc, f30, channels: AudioChannels.stereo),
      );

      final DeviceMediaProfile only1440 = profileOf(
        encode: <ClipFormat, EncodeResult>{
          for (final MapEntry<ClipFormat, EncodeResult> entry
              in flagshipEncode.entries)
            if (entry.key.tier != p2160) entry.key: entry.value,
        },
      );
      expect(
        recommend(only1440).pick,
        f(p1440, hevc, f30, channels: AudioChannels.stereo),
      );
    });

    test('2: a format encodes at ${QualityRules.offeredFactor}× or more to be '
        'picked; between ${QualityRules.slowFactor}× and that it is offered '
        'as slow; below, it is unsupported and hidden', () {
      final DeviceMediaProfile profile = profileOf(
        encode: <ClipFormat, EncodeResult>{
          f(p1080, h264, f30): ok(3.0),
          f(p1080, hevc, f30): ok(1.0),
          f(p1080, hevc, f60): ok(0.9),
          f(p1440, hevc, f30): ok(0.4),
        },
      );
      final QualityRecommendation advice = recommend(profile);

      expect(advice.pick, f(p1080, hevc, f30, channels: AudioChannels.stereo));
      expect(
        advice.of(f(p1080, hevc, f60)),
        const FormatAvailable(realtimeFactor: 0.9),
      );
      expect((advice.of(f(p1080, hevc, f60)) as FormatAvailable).slow, isTrue);
      expect(advice.isOffered(f(p1080, hevc, f60)), isTrue);
      expect(advice.of(f(p1440, hevc, f30)), const FormatUnsupported());
      expect(advice.isOffered(f(p1440, hevc, f30)), isFalse);
    });

    test('3: a year of 2 s clips plus one movie fits '
        '${QualityRules.freeSpaceShare * 100}% of the free space; unknown '
        'free space never demotes', () {
      final ClipFormat ultra = f(p2160, hevc, f60);
      final int year = QualityRules.yearBytes(
        ultra,
        bitrate: EncoderPolicy.bitrateFor(ultra),
      );
      expect(year, 365 * 2 * (42000000 ~/ 8) * 2);

      expect(
        QualityRules.fitsFreeSpace(
          ultra,
          bitrate: EncoderPolicy.bitrateFor(ultra),
          freeBytes: year * 10,
        ),
        isTrue,
      );
      expect(
        QualityRules.fitsFreeSpace(
          ultra,
          bitrate: EncoderPolicy.bitrateFor(ultra),
          freeBytes: year * 10 - 1,
        ),
        isFalse,
      );
      expect(
        recommend(profileOf(encode: flagshipEncode, freeBytes: null)).pick,
        f(p2160, hevc, f60, channels: AudioChannels.stereo),
      );
    });

    test('4: the highest by tier then frame rate wins, HEVC over H.264 at '
        'the same; stereo with a two-channel camera or on iOS, mono '
        'otherwise; never HDR', () {
      final DeviceMediaProfile both = profileOf(
        encode: <ClipFormat, EncodeResult>{
          f(p1080, h264, f30): ok(3.0),
          f(p1080, hevc, f30): ok(2.0),
        },
        camera: FakeCameraCapabilityProbe.basic,
      );
      expect(recommend(both).pick, f(p1080, hevc, f30));
      expect(
        recommend(both, isIOS: true).pick,
        f(p1080, hevc, f30, channels: AudioChannels.stereo),
      );

      final DeviceMediaProfile h264Only = profileOf(
        encode: <ClipFormat, EncodeResult>{
          f(p1080, h264, f30): ok(3.0),
          f(p1080, h264, f60): ok(2.0),
          f(p1080, hevc, f30): const EncodeResult.failed(),
        },
        camera: const CameraCapability(
          maxTier: p1080,
          fps60: true,
          channels: 1,
        ),
      );
      expect(recommend(h264Only).pick, f(p1080, h264, f60));
      for (final ClipFormat choice in recommend(
        flagshipProfile(),
      ).choices.keys) {
        expect(choice.range, DynamicRange.sdr);
      }
    });
  });

  group('fixtures (§6)', () {
    test('a flagship with 480 GB free lands on 4K 60 HEVC stereo, with the '
        'reason', () {
      final QualityRecommendation advice = recommend(flagshipProfile());

      expect(advice.pick, f(p2160, hevc, f60, channels: AudioChannels.stereo));
      expect(advice.checked, isTrue);
      expect(advice.pickFactor, 1.2);
      expect(advice.freeBytes, 480 * gb);
    });

    test('a mid-range phone lands on 1080p30 HEVC', () {
      final DeviceMediaProfile midRange = profileOf(
        encode: <ClipFormat, EncodeResult>{
          f(p1080, h264, f30): ok(1.6),
          f(p1080, hevc, f30): ok(1.3),
          f(p1080, hevc, f60): ok(0.7),
          f(p1440, hevc, f30): ok(0.4),
        },
        camera: FakeCameraCapabilityProbe.basic,
        freeBytes: 64 * gb,
      );

      expect(recommend(midRange).pick, f(p1080, hevc, f30));
    });

    test('a phone without HEVC lands on Standard', () {
      final DeviceMediaProfile noHevc = profileOf(
        encode: <ClipFormat, EncodeResult>{
          f(p1080, h264, f30): ok(1.5),
          f(p1080, hevc, f30): const EncodeResult.failed(),
        },
        camera: FakeCameraCapabilityProbe.basic,
        freeBytes: 64 * gb,
      );
      final QualityRecommendation advice = recommend(noHevc);

      expect(
        advice.pick,
        ClipFormatPreset.standard.format(VideoOrientation.landscape),
      );
      expect(advice.isOffered(f(p1080, hevc, f30)), isFalse);
      expect(
        advice.isOffered(f(p2160, hevc, f60)),
        isFalse,
        reason: 'harder HEVC',
      );
    });

    test('low space demotes the tier until a year fits', () {
      final QualityRecommendation advice = recommend(
        profileOf(encode: flagshipEncode, freeBytes: 20 * gb),
      );

      expect(advice.pick, f(p1080, hevc, f30, channels: AudioChannels.stereo));
    });

    test('without a camera probe (no permission yet) the pick stays at '
        '1080p 30, mono unless on iOS; never checked, or stale, means '
        'Standard with everything offered unchecked', () {
      final DeviceMediaProfile unknownCamera = profileOf(
        encode: flagshipEncode,
        camera: null,
      );
      expect(recommend(unknownCamera).pick, f(p1080, hevc, f30));
      expect(
        recommend(unknownCamera, isIOS: true).pick,
        f(p1080, hevc, f30, channels: AudioChannels.stereo),
      );

      final QualityRecommendation unchecked = recommend(
        null,
        orientation: VideoOrientation.portrait,
      );
      expect(
        unchecked.pick,
        ClipFormatPreset.standard.format(VideoOrientation.portrait),
      );
      expect(unchecked.checked, isFalse);
      expect(unchecked.choices.values, everyElement(const FormatNotChecked()));
      expect(unchecked.isOffered(f(p2160, hevc, f60)), isTrue);
      expect(
        unchecked.presetFormat(ClipFormatPreset.ultra),
        ClipFormatPreset.ultra.format(VideoOrientation.portrait),
      );
    });
  });

  group('what the picker shows', () {
    test('a format not tested reads off the tested ones with its codec: '
        '720p and stereo from 1080p mono, an untested 1440p60 from the '
        'closest harder 4K test that passed (estimated, scaled by the work), one '
        'above a failed easier test as unsupported, else not checked', () {
      final QualityRecommendation advice = recommend(flagshipProfile());

      expect(
        advice.of(f(ResolutionTier.p720, h264, f30)),
        isA<FormatAvailable>().having(
          (FormatAvailable a) => a.estimated,
          'estimated',
          isTrue,
        ),
      );
      expect(
        advice.of(f(p1080, hevc, f30, channels: AudioChannels.stereo)),
        const FormatAvailable(realtimeFactor: 2.8),
      );
      final FormatAvailability qhd60 = advice.of(f(p1440, hevc, f60));
      expect(qhd60, isA<FormatAvailable>());
      // The closest harder HEVC test is 4K 30 (1.5×), not 4K 60.
      const double expected = 1.5 * (3840 * 2160 * 30) / (2560 * 1440 * 60);
      expect(
        (qhd60 as FormatAvailable).realtimeFactor,
        closeTo(expected, 1e-9),
      );
      expect(qhd60.estimated, isTrue);

      final QualityRecommendation weak = recommend(
        profileOf(
          encode: <ClipFormat, EncodeResult>{
            f(p1080, h264, f30): ok(1.5),
            f(p1080, hevc, f30): ok(0.3),
          },
        ),
      );
      expect(weak.of(f(p2160, hevc, f60)), const FormatUnsupported());
      expect(weak.of(f(p1080, h264, f60)), const FormatNotChecked());
    });

    test('a preset the phone can only do demoted shows its best below '
        '(Ultra = 4K 30 when 4K 60 fails), and none at all when nothing '
        'fits', () {
      final QualityRecommendation no4k60 = recommend(
        profileOf(
          encode: <ClipFormat, EncodeResult>{
            ...flagshipEncode,
            f(p2160, hevc, f60): ok(0.4),
            f(p2160, h264, f60): const EncodeResult.failed(),
          },
        ),
      );
      expect(
        no4k60.presetFormat(ClipFormatPreset.ultra),
        f(p2160, hevc, f30, channels: AudioChannels.stereo),
      );
      expect(
        no4k60.presetFormat(ClipFormatPreset.high),
        ClipFormatPreset.high.format(VideoOrientation.landscape),
      );

      final QualityRecommendation h264Only = recommend(
        profileOf(
          encode: <ClipFormat, EncodeResult>{
            f(p1080, h264, f30): ok(1.5),
            f(p1080, hevc, f30): const EncodeResult.failed(),
          },
        ),
      );
      expect(h264Only.presetFormat(ClipFormatPreset.ultra), isNull);
      expect(
        h264Only.presetFormat(ClipFormatPreset.standard),
        ClipFormatPreset.standard.format(VideoOrientation.landscape),
      );
    });

    test('the per-choice line: a 3 s clip at 2.4× takes about 3 s, at 1× '
        'about 4 s; never under 1 s', () {
      expect(QualityRules.saveSeconds(2.4), 3);
      expect(QualityRules.saveSeconds(1), 4);
      expect(QualityRules.saveSeconds(100), 2);
      expect(const FormatAvailable(realtimeFactor: 0.6).saveSeconds, 6);
    });
  });

  // HDR: an HLG format is available
  // when its encode passed (or a harder HLG one did, read off as for SDR)
  // AND the bundled HLG sample decoded; anything less is unsupported
  // (hidden), an unchecked phone included; never the pick; never on H.264.
  group('HLG', () {
    ClipFormat hlg(
      ResolutionTier tier,
      FrameRate fps, {
      AudioChannels channels = AudioChannels.stereo,
      VideoCodec codec = hevc,
    }) => ClipFormat(
      tier: tier,
      orientation: VideoOrientation.landscape,
      codec: codec,
      fps: fps,
      channels: channels,
      range: DynamicRange.hlg,
    );
    final Map<ClipFormat, EncodeResult> hlgEncode = <ClipFormat, EncodeResult>{
      ...flagshipEncode,
      hlg(p1080, f30): ok(1.6),
      hlg(p2160, f30): ok(0.9),
    };
    DeviceMediaProfile hlgProfile({bool decodesSample = true}) =>
        DeviceMediaProfile(
          checkedAt: DateTime(2026, 10, 7),
          appVersion: '2.1.0',
          deviceModel: 'test',
          encode: <String, EncodeResult>{
            for (final MapEntry<ClipFormat, EncodeResult> entry
                in hlgEncode.entries)
              entry.key.toString(): entry.value,
          },
          decode: <String, double>{
            QualityRules.h264DecodeSample: 2.0,
            if (decodesSample) QualityRules.hlgDecodeSample: 1.2,
          },
          camera: FakeCameraCapabilityProbe.flagship,
          freeBytes: 480 * gb,
        );

    test('the candidates: every SDR format and HLG on HEVC alone', () {
      final List<ClipFormat> all = QualityRecommender.candidates(
        VideoOrientation.landscape,
      );
      expect(all, hasLength(48));
      expect(all.where((ClipFormat f) => f.isHdr), hasLength(16));
      expect(
        all.where((ClipFormat f) => f.isHdr).every((ClipFormat f) => f.isValid),
        isTrue,
      );
    });

    test('available with a passed encode and the decoded sample: its own '
        'factor, slow under 1×, a harder HLG test read off for the rest; '
        'never the pick', () {
      final QualityRecommendation advice = recommend(hlgProfile());
      expect(
        advice.of(hlg(p1080, f30)),
        const FormatAvailable(realtimeFactor: 1.6),
      );
      expect(
        advice.of(hlg(p1080, f30, channels: AudioChannels.mono)),
        isA<FormatAvailable>().having(
          (FormatAvailable a) => a.realtimeFactor,
          'factor',
          1.6,
        ),
        reason: 'the layout never changes the answer',
      );
      expect(
        advice.of(hlg(p2160, f30)),
        isA<FormatAvailable>().having(
          (FormatAvailable a) => a.slow,
          'slow',
          isTrue,
        ),
      );
      expect(
        advice.of(hlg(p1080, f60)),
        isA<FormatAvailable>().having(
          (FormatAvailable a) => a.estimated,
          'estimated',
          isTrue,
        ),
        reason: '1080p60 HLG is less work than the 4K30 HLG that passed',
      );
      expect(
        advice.of(hlg(p2160, f60)),
        const FormatUnsupported(),
        reason: 'nothing harder passed: not checked for SDR, hidden for HLG',
      );
      expect(advice.isOffered(hlg(p1080, f30)), isTrue);
      expect(advice.pick.isHdr, isFalse);
      expect(advice.pick, f(p2160, hevc, f60, channels: AudioChannels.stereo));
    });

    test('unsupported without the sample\'s decode though the encode '
        'passed, with a failed encode though the sample decoded, on H.264, '
        'and on an unchecked phone (SDR stays not checked there)', () {
      final QualityRecommendation noSample = recommend(
        hlgProfile(decodesSample: false),
      );
      expect(noSample.of(hlg(p1080, f30)), const FormatUnsupported());
      expect(noSample.of(hlg(p1080, f60)), const FormatUnsupported());
      expect(noSample.isOffered(hlg(p1080, f30)), isFalse);

      final QualityRecommendation failed = recommend(
        DeviceMediaProfile(
          checkedAt: DateTime(2026, 10, 7),
          appVersion: '2.1.0',
          deviceModel: 'test',
          encode: <String, EncodeResult>{
            for (final MapEntry<ClipFormat, EncodeResult> entry
                in flagshipEncode.entries)
              entry.key.toString(): entry.value,
            hlg(p1080, f30).toString(): const EncodeResult.failed(),
          },
          decode: <String, double>{QualityRules.hlgDecodeSample: 1.2},
          camera: FakeCameraCapabilityProbe.flagship,
          freeBytes: 480 * gb,
        ),
      );
      expect(failed.of(hlg(p1080, f30)), const FormatUnsupported());

      expect(
        recommend(hlgProfile()).of(hlg(p1080, f30, codec: h264)),
        const FormatUnsupported(),
      );

      final QualityRecommendation unchecked = recommend(null);
      expect(unchecked.of(hlg(p1080, f30)), const FormatUnsupported());
      expect(unchecked.of(f(p1080, hevc, f30)), const FormatNotChecked());
    });
  });
}

DeviceMediaProfile flagshipProfile() => profileOf(encode: flagshipEncode);
