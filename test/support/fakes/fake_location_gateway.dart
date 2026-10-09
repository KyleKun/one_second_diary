import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/geo_place.dart';
import 'package:one_second_diary/core/platform/geo_position.dart';
import 'package:one_second_diary/core/platform/location_gateway.dart';

/// A [LocationGateway] with a scripted position and geocoder.
///
/// `currentPosition` returns [position], or throws [positionError] when set.
/// `placesAt` consumes [placeResults] in order (a `List<GeoPlace>` is
/// returned, anything else is thrown, to script retries), then returns
/// [places]. `positionOf` answers [positions] by address, null for any
/// other, or throws [lookupError] when set. [localesRequested] records
/// the locale of every lookup.
class FakeLocationGateway extends Fake implements LocationGateway {
  final Map<String, GeoPosition> positions = <String, GeoPosition>{};
  Object? lookupError;
  bool serviceEnabled = true;
  GeoPosition position = const GeoPosition(latitude: 35.71, longitude: 139.79);
  Object? positionError;
  List<GeoPlace> places = const <GeoPlace>[
    GeoPlace(
      locality: 'Tokyo',
      subAdministrativeArea: null,
      administrativeArea: 'Tokyo',
      country: 'Japan',
    ),
  ];
  final Queue<Object> placeResults = Queue<Object>();
  final List<String> localesRequested = <String>[];

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<GeoPosition> currentPosition({required Duration timeLimit}) async {
    final Object? error = positionError;
    if (error != null) throw error;
    return position;
  }

  @override
  Future<List<GeoPlace>> placesAt(
    GeoPosition position, {
    required String localeIdentifier,
  }) async {
    localesRequested.add(localeIdentifier);
    if (placeResults.isEmpty) return places;
    final Object next = placeResults.removeFirst();
    if (next is List<GeoPlace>) return next;
    throw next;
  }

  @override
  Future<GeoPosition?> positionOf(
    String address, {
    required String localeIdentifier,
  }) async {
    localesRequested.add(localeIdentifier);
    final Object? error = lookupError;
    if (error != null) throw error;
    return positions[address];
  }
}
