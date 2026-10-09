import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/app_info_gateway.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// [AppInfoGateway] over `package_info_plus`.
final class PackageInfoPlusGateway implements AppInfoGateway {
  /// The DI container passes `PackageInfo.fromPlatform`; the gateway calls no
  /// plugin global itself, so tests run on any host.
  PackageInfoPlusGateway({required this._read, required this._logger});

  final Future<PackageInfo> Function() _read;
  final AppLogger _logger;

  static const String _tag = 'APP';

  /// What [version] answers when the platform cannot tell.
  static const String unknownVersion = 'unknown';

  /// The first answer, shared by every later call; null when the platform
  /// could not tell.
  Future<PackageInfo?>? _info;

  @override
  Future<String> version() async =>
      (await _readInfo())?.version ?? unknownVersion;

  @override
  Future<String?> buildNumber() async =>
      switch ((await _readInfo())?.buildNumber.trim()) {
        final String build when build.isNotEmpty => build,
        _ => null,
      };

  Future<PackageInfo?> _readInfo() => _info ??= _readOnce();

  Future<PackageInfo?> _readOnce() async {
    try {
      return await _read();
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not read the app version',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
