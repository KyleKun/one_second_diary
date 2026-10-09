import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:one_second_diary/core/platform/geo_place.dart';
import 'package:one_second_diary/core/platform/geo_position.dart';
import 'package:one_second_diary/core/platform/geolocator_location_gateway.dart';

import '../../support/track_1d/fake_location_platforms.dart';

void main() {
  test('asks for one fix at medium accuracy within the time limit, as v1.7, '
      'and names the place in the app language, empty names as none', () async {
    final GeolocatorPlatform originalGeolocator = GeolocatorPlatform.instance;
    final FakeGeolocatorPlatform geolocator = FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = geolocator;
    addTearDown(() => GeolocatorPlatform.instance = originalGeolocator);
    final GeocodingPlatform? originalGeocoding = GeocodingPlatform.instance;
    final FakeGeocodingPlatform geocoding = FakeGeocodingPlatform()
      ..placemarks = const <Placemark>[
        Placemark(
          locality: '',
          subAdministrativeArea: 'Chuo',
          administrativeArea: 'Tokyo',
          country: 'Japan',
        ),
      ];
    GeocodingPlatform.instance = geocoding;
    // Null in tests (no plugin registered), and the setter refuses null.
    if (originalGeocoding != null) {
      addTearDown(() => GeocodingPlatform.instance = originalGeocoding);
    }
    const GeolocatorLocationGateway gateway = GeolocatorLocationGateway();

    final GeoPosition position = await gateway.currentPosition(
      timeLimit: const Duration(seconds: 20),
    );
    final List<GeoPlace> places = await gateway.placesAt(
      position,
      localeIdentifier: 'pt',
    );

    expect(position, const GeoPosition(latitude: 35.71, longitude: 139.79));
    final LocationSettings settings = geolocator.settingsRequested.single!;
    expect(settings.accuracy, LocationAccuracy.medium);
    expect(settings.timeLimit, const Duration(seconds: 20));
    expect(geocoding.calls, <String>['locale:pt', 'lookup:35.71,139.79']);
    expect(places, const <GeoPlace>[
      GeoPlace(
        locality: null,
        subAdministrativeArea: 'Chuo',
        administrativeArea: 'Tokyo',
        country: 'Japan',
      ),
    ]);
  });
}
