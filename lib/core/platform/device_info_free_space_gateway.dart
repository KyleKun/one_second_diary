import 'package:device_info_plus/device_info_plus.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/free_space_gateway.dart';

/// [FreeSpaceGateway] over `device_info_plus`: Android's
/// `StatFs(Environment.getDataDirectory()).getFreeBytes()`. On Android the
/// shared storage (`DCIM/`) is emulated on the same data partition as the
/// app's scratch and cache folders, so one number covers every copy a
/// movie makes.
///
/// Android only: iOS reports `NSFileSystemFreeSize`, which leaves out the
/// space the system frees on demand, so it could stop a movie that fits;
/// there the check answers "unknown" and the build fails early on its own
/// if the phone fills up. The plugin caches its answer per instance, so
/// the caller passes [androidInfo] to read the facts afresh each time.
final class DeviceInfoFreeSpaceGateway implements FreeSpaceGateway {
  DeviceInfoFreeSpaceGateway({
    required this._isAndroid,
    required this._androidInfo,
    required this._logger,
  });

  final bool _isAndroid;
  final Future<AndroidDeviceInfo> Function() _androidInfo;
  final AppLogger _logger;

  static const String _tag = 'CREATE MOVIE';

  @override
  Future<int?> freeBytes() async {
    if (!_isAndroid) return null;
    try {
      final int free = (await _androidInfo()).freeDiskSize;
      if (free >= 0) return free;
      _logger.warning(_tag, 'The phone reported $free bytes free');
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not read the free space; making the movie anyway',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return null;
  }
}
