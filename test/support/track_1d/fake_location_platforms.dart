import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// The `geolocator` platform, scripted, to test `GeolocatorLocationGateway`
/// on the host. It extends the platform class because the plugin checks
/// its token when an instance is set (an `implements` fake is rejected).
///
/// [settingsRequested] records the settings of every fix request.
class FakeGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  Position position = fakePosition(latitude: 35.71, longitude: 139.79);
  final List<LocationSettings?> settingsRequested = <LocationSettings?>[];

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    settingsRequested.add(locationSettings);
    return position;
  }
}

/// A [Position] with only a latitude and a longitude worth reading.
Position fakePosition({required double latitude, required double longitude}) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.utc(2024, 1, 5),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// The `geocoding` platform, scripted. [calls] records, in order, every
/// locale set (`locale:<id>`) and every lookup (`lookup:<lat>,<lon>`).
class FakeGeocodingPlatform extends GeocodingPlatform {
  List<Placemark> placemarks = const <Placemark>[];
  final List<String> calls = <String>[];

  @override
  Future<void> setLocaleIdentifier(String localeIdentifier) async {
    calls.add('locale:$localeIdentifier');
  }

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    calls.add('lookup:$latitude,$longitude');
    return placemarks;
  }
}
