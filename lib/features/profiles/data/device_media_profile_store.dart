import 'dart:convert';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/app_info_gateway.dart';
import 'package:one_second_diary/core/platform/device_info_gateway.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';

/// The stored result of the phone check (`deviceMediaProfile`): the only
/// writer of that key. [current] gives it only when this phone and app
/// version made it.
///
/// A plain class (not final), so cubit tests can fake it.
class DeviceMediaProfileStore {
  DeviceMediaProfileStore({
    required this._prefs,
    required this._appInfo,
    required this._deviceInfo,
    required this._logger,
  });

  final PrefsStore _prefs;
  final AppInfoGateway _appInfo;
  final DeviceInfoGateway _deviceInfo;
  final AppLogger _logger;

  static const String _tag = 'PHONE_CHECK';

  /// The stored profile, whatever phone made it; null when the check never
  /// ran or the value is not one (logged).
  DeviceMediaProfile? read() {
    final String stored = _prefs.read(PrefKeys.deviceMediaProfile);
    if (stored.isEmpty) return null;
    try {
      final DeviceMediaProfile? profile = DeviceMediaProfile.fromJson(
        jsonDecode(stored),
      );
      if (profile == null) {
        _logger.warning(_tag, 'The stored phone check is not readable');
      }
      return profile;
    } on FormatException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'The stored phone check is not JSON',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// The stored profile when this phone and app version made it, else
  /// null (never ran, unreadable, or stale).
  Future<DeviceMediaProfile?> current() async {
    final DeviceMediaProfile? stored = read();
    if (stored == null) return null;
    return await isStale(stored) ? null : stored;
  }

  /// Whether [profile] was made by another app version or phone.
  Future<bool> isStale(DeviceMediaProfile profile) async => profile.isStaleFor(
    appVersion: await appVersion(),
    deviceModel: await deviceModel(),
  );

  /// Whether a stored profile exists and was made on another phone: the
  /// one case that re-runs the check quietly.
  Future<bool> isFromAnotherPhone() async {
    final DeviceMediaProfile? stored = read();
    if (stored == null) return false;
    return stored.isFromAnotherPhone(await deviceModel());
  }

  /// Stores [profile] as the phone's result.
  Future<void> write(DeviceMediaProfile profile) =>
      _prefs.write(PrefKeys.deviceMediaProfile, jsonEncode(profile.toJson()));

  /// The installed app version, as a profile records it.
  Future<String> appVersion() => _appInfo.version();

  /// The phone, as a profile records it: the device part of
  /// `DeviceInfoGateway.description` (`Google Pixel 8`, `iPhone15,2`),
  /// without the system version, so an OS update alone is no new phone.
  Future<String> deviceModel() async =>
      modelOf(await _deviceInfo.description());

  /// `Android 14 (SDK 34), Google Pixel 8` → `Google Pixel 8`;
  /// `iOS 17.5, iPhone15,2` → `iPhone15,2`; a description without the
  /// separator stays as it is.
  static String modelOf(String description) {
    final int split = description.indexOf(', ');
    return split < 0 ? description : description.substring(split + 2);
  }
}
