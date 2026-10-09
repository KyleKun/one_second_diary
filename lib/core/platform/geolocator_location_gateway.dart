import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:one_second_diary/core/platform/geo_place.dart';
import 'package:one_second_diary/core/platform/geo_position.dart';
import 'package:one_second_diary/core/platform/location_gateway.dart';

/// [LocationGateway] over `geolocator` (the fix) and `geocoding` (the
/// place name, through the phone's own geocoder).
///
/// Permissions are not asked here: `PermissionGateway` owns
/// `AppPermission.location`, so geolocator's own permission API is unused.
final class GeolocatorLocationGateway implements LocationGateway {
  const GeolocatorLocationGateway();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  /// One fix at medium accuracy (a city is all the stamp needs, and medium
  /// is much faster to get indoors than high).
  @override
  Future<GeoPosition> currentPosition({required Duration timeLimit}) async {
    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: timeLimit,
      ),
    );
    return GeoPosition(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  /// The plugin's locale is global state, so it is set right before each
  /// lookup.
  @override
  Future<List<GeoPlace>> placesAt(
    GeoPosition position, {
    required String localeIdentifier,
  }) async {
    await setLocaleIdentifier(localeIdentifier);
    final List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    return <GeoPlace>[
      for (final Placemark placemark in placemarks)
        GeoPlace(
          locality: _nonEmpty(placemark.locality),
          subAdministrativeArea: _nonEmpty(placemark.subAdministrativeArea),
          administrativeArea: _nonEmpty(placemark.administrativeArea),
          country: _nonEmpty(placemark.country),
        ),
    ];
  }

  /// The plugin's locale is global state, so it is set right before each
  /// lookup. An unknown address answers an empty list on some platforms
  /// and throws on others; both read as null.
  @override
  Future<GeoPosition?> positionOf(
    String address, {
    required String localeIdentifier,
  }) async {
    await setLocaleIdentifier(localeIdentifier);
    final List<Location> locations;
    try {
      locations = await locationFromAddress(address);
    } on NoResultFoundException {
      return null;
    }
    if (locations.isEmpty) return null;
    final Location first = locations.first;
    return GeoPosition(latitude: first.latitude, longitude: first.longitude);
  }

  /// The plugin reports a missing field as `''` on some platforms.
  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;
}
