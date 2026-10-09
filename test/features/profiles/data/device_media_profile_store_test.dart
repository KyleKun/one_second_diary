// The stored phone check: read, written, and current only when this phone
// and app version made it.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/profiles/data/device_media_profile_store.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';

import '../../../shared/fakes/fake_app_info_gateway.dart';
import '../../../support/support.dart';

void main() {
  late MemoryLogSink log;
  late FakeAppInfoGateway appInfo;
  late FakeDeviceInfoGateway deviceInfo;

  setUp(() {
    log = MemoryLogSink();
    appInfo = FakeAppInfoGateway(appVersion: '2.1.0');
    deviceInfo = FakeDeviceInfoGateway(sdkInt: 34);
  });

  Future<DeviceMediaProfileStore> storeOver(Map<String, Object> prefs) async {
    final PrefsStore store = await openLegacyPrefs(prefs);
    return DeviceMediaProfileStore(
      prefs: store,
      appInfo: appInfo,
      deviceInfo: deviceInfo,
      logger: memoryLogger(log),
    );
  }

  DeviceMediaProfile profileFrom({
    String appVersion = '2.1.0',
    String deviceModel = 'Google Pixel 8',
  }) => DeviceMediaProfile(
    checkedAt: DateTime(2026, 10, 7),
    appVersion: appVersion,
    deviceModel: deviceModel,
  );

  test('nothing stored, or a value that is not a profile, reads as null '
      '(the latter logged); a written profile reads back', () async {
    final DeviceMediaProfileStore empty = await storeOver(legacyPrefs());
    expect(empty.read(), isNull);
    expect(await empty.current(), isNull);

    final DeviceMediaProfileStore broken = await storeOver(
      legacyPrefs(extra: <String, Object>{'deviceMediaProfile': '{"v":'}),
    );
    expect(broken.read(), isNull);
    expect(log.lines, isNotEmpty);

    final DeviceMediaProfile profile = profileFrom();
    await empty.write(profile);
    expect(empty.read(), profile);
    expect(await empty.current(), profile);
  });

  test('the device model is the device part of the description, so an OS '
      'update is not a new phone; a profile from another version or phone '
      'is stale (null as current) and the other phone is told apart', () async {
    expect(
      DeviceMediaProfileStore.modelOf('Android 14 (SDK 34), Google Pixel 8'),
      'Google Pixel 8',
    );
    expect(
      DeviceMediaProfileStore.modelOf('iOS 17.5, iPhone15,2'),
      'iPhone15,2',
    );
    expect(DeviceMediaProfileStore.modelOf('unknown device'), 'unknown device');

    final DeviceMediaProfileStore store = await storeOver(legacyPrefs());
    expect(await store.deviceModel(), 'Google Pixel 8');
    expect(await store.appVersion(), '2.1.0');

    await store.write(profileFrom(appVersion: '2.0.0'));
    expect(await store.current(), isNull);
    expect(await store.isFromAnotherPhone(), isFalse);

    await store.write(profileFrom(deviceModel: 'Google Pixel 9'));
    expect(await store.current(), isNull);
    expect(await store.isFromAnotherPhone(), isTrue);
    expect(store.read(), isNotNull, reason: 'stale is still stored');
  });
}
