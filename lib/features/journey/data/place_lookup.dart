import 'package:one_second_diary/core/location/location_service.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/geo_place.dart';
import 'package:one_second_diary/core/platform/geo_position.dart';
import 'package:one_second_diary/core/platform/location_gateway.dart';
import 'package:one_second_diary/features/journey/domain/geo_point.dart';

/// Finds where a typed place name is, through the phone's own geocoder:
/// only the name is sent, never a clip.
///
/// Never throws: a failed lookup is logged and answers
/// [PlaceLookupResult.failed].
class PlaceLookup {
  PlaceLookup({required this._location, required this._logger});

  final LocationGateway _location;
  final AppLogger _logger;

  static const String _tag = 'PLACES';

  /// The coordinates of [query] ("Lisbon, Portugal"), named in
  /// [localeIdentifier] (the app language), with what the geocoder calls
  /// that spot so the user can check the match: [PlaceFound],
  /// [PlaceUnknown] when the geocoder knows no such place, or
  /// [PlaceLookupFailed] when it could not answer (offline).
  Future<PlaceLookupResult> find(
    String query, {
    required String localeIdentifier,
  }) async {
    final GeoPosition? position;
    try {
      position = await _location.positionOf(
        query,
        localeIdentifier: localeIdentifier,
      );
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not look a place name up',
        error: error,
        stackTrace: stackTrace,
      );
      return const PlaceLookupResult.failed();
    }
    if (position == null) return const PlaceLookupResult.unknown();
    GeoPlace? place;
    try {
      final List<GeoPlace> places = await _location.placesAt(
        position,
        localeIdentifier: localeIdentifier,
      );
      if (places.isNotEmpty) place = places.first;
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not name a looked-up spot',
        error: error,
        stackTrace: stackTrace,
      );
    }
    final String? name = place == null
        ? null
        : LocationService.placeNameOf(place);
    return PlaceLookupResult.found(
      GeoPoint(position.latitude, position.longitude),
      name: name == null || name.isEmpty ? null : name,
      country: place?.country,
    );
  }
}

/// What a name lookup gave.
sealed class PlaceLookupResult {
  const PlaceLookupResult();

  const factory PlaceLookupResult.found(
    GeoPoint at, {
    String? name,
    String? country,
  }) = PlaceFound;

  const factory PlaceLookupResult.unknown() = PlaceUnknown;

  const factory PlaceLookupResult.failed() = PlaceLookupFailed;
}

final class PlaceFound extends PlaceLookupResult {
  const PlaceFound(this.at, {this.name, this.country});

  final GeoPoint at;

  /// "City, Country" as the geocoder names the spot; null when it could not.
  final String? name;

  /// The spot's country as the geocoder names it; null when it could not.
  final String? country;
}

/// The geocoder answered: no such place.
final class PlaceUnknown extends PlaceLookupResult {
  const PlaceUnknown();
}

/// The geocoder could not answer (offline): the rest of a run would fail
/// the same way.
final class PlaceLookupFailed extends PlaceLookupResult {
  const PlaceLookupFailed();
}
