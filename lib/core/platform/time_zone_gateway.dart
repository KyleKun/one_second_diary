/// The device's time zone (`flutter_timezone`).
///
/// Dart's `DateTime` knows the local offset but not the zone's name, and
/// the `timezone` package needs the name to plan wall-clock times across
/// daylight-saving changes (see `LocalTimeZone`).
abstract interface class TimeZoneGateway {
  /// The IANA name of the device's current zone, e.g. `Europe/Berlin`.
  /// Throws when the platform cannot tell.
  Future<String> localTimeZoneName();
}
