import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/platform/device_info_plus_gateway.dart';

/// A plugin whose platform channel is broken.
class _BrokenDeviceInfoPlugin extends Fake implements DeviceInfoPlugin {
  @override
  Future<AndroidDeviceInfo> get androidInfo async =>
      throw PlatformException(code: 'error', message: 'channel closed');
}

void main() {
  // null means "not Android", so a failure must never read as null: the
  // storage permission matrix would take the iOS path.
  test('a plugin failure on Android is a StorageException, never a null '
      'SDK level', () async {
    final DeviceInfoPlusGateway gateway = DeviceInfoPlusGateway(
      plugin: _BrokenDeviceInfoPlugin(),
      isAndroid: true,
    );

    await expectLater(
      gateway.androidSdkInt(),
      throwsA(
        isA<StorageException>().having(
          (StorageException e) => e.cause,
          'cause',
          isA<PlatformException>(),
        ),
      ),
    );
  });
}
