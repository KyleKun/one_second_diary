import 'package:one_second_diary/core/platform/geo_place.dart';
import 'package:one_second_diary/core/platform/geo_position.dart';

/// Device location and reverse geocoding (`geolocator` + `geocoding`).
///
/// The place name is looked up through the phone's own location service.
/// Permission handling goes through `PermissionGateway`
/// (`AppPermission.location`); retries, the city fallback and caching live
/// above this boundary (`LocationService`).
abstract interface class LocationGateway {
  /// Whether the device's location service is switched on.
  Future<bool> isServiceEnabled();

  /// The current position at medium accuracy. Throws when no fix arrives
  /// within [timeLimit] or the service fails.
  Future<GeoPosition> currentPosition({required Duration timeLimit});

  /// Places at [position], named in [localeIdentifier] (the app language,
  /// e.g. `pt`). Throws when the lookup fails; may return an empty list.
  Future<List<GeoPlace>> placesAt(
    GeoPosition position, {
    required String localeIdentifier,
  });

  /// Where the place named [address] ("Lisbon, Portugal") is, as the
  /// geocoder reads it in [localeIdentifier]; null when it knows no such
  /// place. Throws when the lookup fails (offline).
  Future<GeoPosition?> positionOf(
    String address, {
    required String localeIdentifier,
  });
}
