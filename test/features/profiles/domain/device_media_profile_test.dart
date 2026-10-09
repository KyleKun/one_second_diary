// The phone check's result: a JSON round trip, a malformed value reads as
// "never ran", and stale detection (another app version or phone).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';

import '../../../shared/fakes/fake_device_media_check_runner.dart';

void main() {
  final ClipFormat standard = FakeDeviceMediaCheckRunner.format();
  final ClipFormat ultra = FakeDeviceMediaCheckRunner.format(
    tier: ResolutionTier.p2160,
    codec: VideoCodec.hevc,
    fps: FrameRate.f60,
  );

  DeviceMediaProfile flagship() => DeviceMediaProfile(
    checkedAt: DateTime(2026, 10, 7, 10, 30),
    appVersion: '2.1.0',
    deviceModel: 'Google Pixel 8',
    encode: <String, EncodeResult>{
      standard.toString(): const EncodeResult(ok: true, realtimeFactor: 3.2),
      ultra.toString(): const EncodeResult(ok: true, realtimeFactor: 1.4),
      '2160p60-h264-mono-sdr': const EncodeResult.failed(),
    },
    decode: const <String, double>{'iphone-4k60-h264': 2.5, 'android-hlg': 0.9},
    camera: const CameraCapability(
      maxTier: ResolutionTier.p2160,
      fps60: true,
      channels: 2,
    ),
    freeBytes: 480 * 1000 * 1000 * 1000,
  );

  test('round trips through JSON, with every fact; the encode results are '
      'found by format whatever its orientation', () {
    final DeviceMediaProfile profile = flagship();

    final String stored = jsonEncode(profile.toJson());
    final DeviceMediaProfile? read = DeviceMediaProfile.fromJson(
      jsonDecode(stored),
    );

    expect(read, profile);
    expect(
      read!.encodeOf(ultra.withOrientation(VideoOrientation.portrait)),
      const EncodeResult(ok: true, realtimeFactor: 1.4),
    );
    expect(
      read.encodeOf(
        FakeDeviceMediaCheckRunner.format(tier: ResolutionTier.p720),
      ),
      isNull,
    );
    expect(read.testedFormats.map((ClipFormat f) => f.toString()), <String>[
      '1080p30-h264-mono-sdr',
      '2160p60-hevc-mono-sdr',
      '2160p60-h264-mono-sdr',
    ]);
  });

  test('a profile without a camera or free space keeps them null', () {
    final DeviceMediaProfile bare = DeviceMediaProfile(
      checkedAt: DateTime(2026, 10, 7),
      appVersion: '2.1.0',
      deviceModel: 'iPhone15,2',
    );

    final DeviceMediaProfile? read = DeviceMediaProfile.fromJson(
      jsonDecode(jsonEncode(bare.toJson())),
    );

    expect(read, bare);
    expect(read!.camera, isNull);
    expect(read.freeBytes, isNull);
  });

  test('anything that is not a complete profile of this version reads as '
      'null (never ran): wrong version, missing fields, a bad date, a '
      'non-object; a malformed entry inside is skipped', () {
    final Map<String, Object?> good = flagship().toJson();
    for (final Object? bad in <Object?>[
      null,
      'not an object',
      <String, Object?>{...good, 'version': 2},
      <String, Object?>{...good}..remove('deviceModel'),
      <String, Object?>{...good, 'checkedAt': 'yesterday'},
      <String, Object?>{...good, 'appVersion': 3},
    ]) {
      expect(DeviceMediaProfile.fromJson(bad), isNull, reason: '$bad');
    }

    final DeviceMediaProfile? partial = DeviceMediaProfile.fromJson(
      <String, Object?>{
        ...good,
        'encode': <String, Object?>{
          '1080p30-h264-mono-sdr': <String, Object?>{'ok': true, 'factor': 2},
          '1080p30-hevc-mono-sdr': 'broken',
        },
        'decode': <String, Object?>{'a': 1.5, 'b': 'slow'},
        'camera': <String, Object?>{'maxTier': '8K'},
        'freeBytes': 'lots',
      },
    );

    expect(partial, isNotNull);
    expect(partial!.encode, <String, EncodeResult>{
      '1080p30-h264-mono-sdr': const EncodeResult(ok: true, realtimeFactor: 2),
    });
    expect(partial.decode, <String, double>{'a': 1.5});
    expect(partial.camera, isNull);
    expect(partial.freeBytes, isNull);
  });

  test('stale when the app version or the device model differs; from '
      'another phone only when the model differs', () {
    final DeviceMediaProfile profile = flagship();

    expect(
      profile.isStaleFor(appVersion: '2.1.0', deviceModel: 'Google Pixel 8'),
      isFalse,
    );
    expect(
      profile.isStaleFor(appVersion: '2.2.0', deviceModel: 'Google Pixel 8'),
      isTrue,
    );
    expect(
      profile.isStaleFor(appVersion: '2.1.0', deviceModel: 'Google Pixel 9'),
      isTrue,
    );
    expect(profile.isFromAnotherPhone('Google Pixel 8'), isFalse);
    expect(profile.isFromAnotherPhone('Google Pixel 9'), isTrue);
  });
}
