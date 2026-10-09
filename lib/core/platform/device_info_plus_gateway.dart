import 'package:device_info_plus/device_info_plus.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/platform/device_info_gateway.dart';

/// [DeviceInfoGateway] over `device_info_plus`.
final class DeviceInfoPlusGateway implements DeviceInfoGateway {
  /// Bootstrap passes `DeviceInfoPlugin()` and `Platform.isAndroid`; the
  /// gateway reads neither global itself, so tests run on any host.
  DeviceInfoPlusGateway({required this._plugin, required this._isAndroid});

  final DeviceInfoPlugin _plugin;
  final bool _isAndroid;

  /// `Build.VERSION.SDK_INT`. The plugin caches the answer.
  @override
  Future<int?> androidSdkInt() async {
    if (!_isAndroid) return null;
    try {
      return (await _plugin.androidInfo).version.sdkInt;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StorageException('Could not read the Android SDK level', cause: error),
        stackTrace,
      );
    }
  }

  @override
  Future<String> description() async {
    try {
      if (_isAndroid) {
        final AndroidDeviceInfo info = await _plugin.androidInfo;
        return 'Android ${info.version.release} (SDK ${info.version.sdkInt}), '
            '${info.manufacturer} ${info.model}';
      }
      final IosDeviceInfo info = await _plugin.iosInfo;
      return 'iOS ${info.systemVersion}, ${info.utsname.machine}';
    } on Object catch (error) {
      return 'unknown device ($error)';
    }
  }
}
