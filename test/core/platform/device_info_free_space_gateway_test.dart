// The free space the movie check reads: Android's StatFs of the data
// partition, which holds the gallery too.

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/device_info_free_space_gateway.dart';

import '../../support/support.dart';

/// Android's device facts with [free] bytes free.
AndroidDeviceInfo _android({required int free}) =>
    AndroidDeviceInfo.setMockInitialValues(
      version: AndroidBuildVersion.setMockInitialValues(
        codename: 'REL',
        incremental: '1',
        previewSdkInt: 0,
        release: '14',
        sdkInt: 34,
        securityPatch: '2026-09-01',
      ),
      board: 'board',
      bootloader: 'bootloader',
      brand: 'brand',
      device: 'device',
      display: 'display',
      fingerprint: 'fingerprint',
      hardware: 'hardware',
      host: 'host',
      id: 'id',
      manufacturer: 'manufacturer',
      model: 'model',
      product: 'product',
      name: 'name',
      supported32BitAbis: const <String>[],
      supported64BitAbis: const <String>['arm64-v8a'],
      supportedAbis: const <String>['arm64-v8a'],
      tags: 'release-keys',
      type: 'user',
      isPhysicalDevice: true,
      freeDiskSize: free,
      totalDiskSize: 128000000000,
      systemFeatures: const <String>[],
      isLowRamDevice: false,
      physicalRamSize: 8000,
      availableRamSize: 4000,
    );

void main() {
  test('on Android, the free bytes the phone has now, read afresh each '
      'time; unknown on iOS, when the plugin fails (logged) or answers '
      'nonsense', () async {
    final MemoryLogSink log = MemoryLogSink();
    int free = 5000000000;
    final DeviceInfoFreeSpaceGateway android = DeviceInfoFreeSpaceGateway(
      isAndroid: true,
      androidInfo: () async => _android(free: free),
      logger: memoryLogger(log),
    );
    expect(await android.freeBytes(), 5000000000);
    free = 1200;
    expect(await android.freeBytes(), 1200);

    final DeviceInfoFreeSpaceGateway iOS = DeviceInfoFreeSpaceGateway(
      isAndroid: false,
      androidInfo: () => fail('asked the plugin'),
      logger: memoryLogger(log),
    );
    expect(await iOS.freeBytes(), isNull);

    final DeviceInfoFreeSpaceGateway broken = DeviceInfoFreeSpaceGateway(
      isAndroid: true,
      androidInfo: () async =>
          throw PlatformException(code: 'error', message: 'channel closed'),
      logger: memoryLogger(log),
    );
    final DeviceInfoFreeSpaceGateway negative = DeviceInfoFreeSpaceGateway(
      isAndroid: true,
      androidInfo: () async => _android(free: -1),
      logger: memoryLogger(log),
    );

    expect(await broken.freeBytes(), isNull);
    expect(await negative.freeBytes(), isNull);
    expect(
      log.lines.where((String line) => line.contains('[CREATE MOVIE]')),
      isNotEmpty,
    );
  });
}
