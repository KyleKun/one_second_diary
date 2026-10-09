import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/time_zone_gateway.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Makes `tz.local` the device's zone, so reminders are planned at the
/// user's wall-clock time on every day, across daylight-saving changes.
///
/// Uses the `latest_all` database: phones still report old zone names
/// (`Asia/Calcutta`, `Europe/Kiev`, `GMT`) that the default database leaves
/// out, and a miss would put every reminder on UTC.
final class LocalTimeZone {
  LocalTimeZone({required this._gateway, required this._logger});

  final TimeZoneGateway _gateway;
  final AppLogger _logger;

  /// Loads the zone database (once per process), asks the device for its
  /// zone and makes it `tz.local`. Call it before each plan: the user may
  /// have travelled since the last one.
  ///
  /// Never throws: an unknown zone or a platform failure falls back to UTC
  /// (logged), where reminders still fire, only at UTC wall-clock times.
  Future<tz.Location> resolve() async {
    // Loading again would also reset tz.local to UTC.
    if (!tz.timeZoneDatabase.isInitialized) tz_data.initializeTimeZones();
    tz.Location location;
    try {
      location = tz.getLocation(await _gateway.localTimeZoneName());
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'NOTIFICATIONS',
        'Unknown device time zone, reminders use UTC',
        error: error,
        stackTrace: stackTrace,
      );
      location = tz.UTC;
    }
    tz.setLocalLocation(location);
    return location;
  }
}
