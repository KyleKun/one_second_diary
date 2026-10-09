import 'package:one_second_diary/core/location/location_result.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/permissions/access_outcome.dart';
import 'package:one_second_diary/core/permissions/permission_feature.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/platform/geo_place.dart';
import 'package:one_second_diary/core/platform/geo_position.dart';
import 'package:one_second_diary/core/platform/location_gateway.dart';

/// Finds the place to stamp on a clip (geotagging, opt-in and off by
/// default).
///
/// The result says why nothing was found, so the editor can switch
/// geotagging off and show the matching state.
///
/// Coordinates and place names are logged only as verbose lines: normal
/// logs, which "Report error" sends, never locate the user.
///
/// A plain class (not final), so cubit tests can fake it.
class LocationService {
  LocationService({
    required this._location,
    required this._permissions,
    required this._logger,
  });

  /// How long to wait for a position fix.
  static const Duration fixTimeLimit = Duration(seconds: 20);

  /// Reverse-geocoding attempts and the pause between them. The system
  /// geocoder needs the network, which is often briefly missing.
  static const int placeAttempts = 3;
  static const Duration placeRetryDelay = Duration(seconds: 1);

  static const String _tag = 'GEOLOCATION';

  final LocationGateway _location;
  final PermissionRequester _permissions;
  final AppLogger _logger;

  /// The current position and its place name, named in [localeIdentifier]
  /// (the app language, e.g. `pt`), as "City, Country".
  ///
  /// In order: the location service must be on; the permission is asked
  /// just in time (the first time geotagging is on); then one fix at medium
  /// accuracy within [fixTimeLimit]; then up to [placeAttempts] lookups
  /// [placeRetryDelay] apart.
  ///
  /// Never throws: a platform error at any step is logged and reported as a
  /// [LocationFailed], so the editor always gets a state to show.
  Future<LocationResult> locate({required String localeIdentifier}) async {
    _logger.info(_tag, 'Getting location...');
    if (await _checkAccess() case final LocationFailed refused) return refused;
    final GeoPosition position;
    try {
      position = await _location.currentPosition(timeLimit: fixTimeLimit);
    } on Object catch (error, stackTrace) {
      return _noPosition('No position', error: error, stackTrace: stackTrace);
    }
    final GeoPlace? place = await _placeAt(position, localeIdentifier);
    if (place == null) return const LocationFailed(LocationFailure.offline);
    final String placeName = placeNameOf(place);
    _logger
      ..info(_tag, 'Location found')
      ..verbose(
        _tag,
        '${position.latitude}, ${position.longitude}: $placeName',
      );
    return LocationFound(position: position, placeName: placeName);
  }

  /// "City, Country", the stamp text. The city falls back to the district,
  /// then the region. A missing part is left out.
  static String placeNameOf(GeoPlace place) {
    final String? city =
        place.locality ??
        place.subAdministrativeArea ??
        place.administrativeArea;
    return <String>[?city, ?place.country].join(', ');
  }

  /// The location service, then the permission; null when both allow a
  /// fix.
  ///
  /// A platform error in either is [LocationFailure.noPosition], not a
  /// refusal: for example `permission_handler` throws "A request for
  /// permissions is already running" when the geotagging switch is tapped
  /// twice quickly.
  Future<LocationFailed?> _checkAccess() async {
    try {
      if (!await _location.isServiceEnabled()) {
        _logger.warning(_tag, 'Location services are off');
        return const LocationFailed(LocationFailure.serviceDisabled);
      }
    } on Object catch (error, stackTrace) {
      return _noPosition(
        'Could not check the location service',
        error: error,
        stackTrace: stackTrace,
      );
    }
    try {
      return switch (await _permissions.request(PermissionFeature.geotagging)) {
        AccessOutcome.granted => null,
        AccessOutcome.denied => const LocationFailed(
          LocationFailure.permissionDenied,
        ),
        AccessOutcome.blocked => const LocationFailed(
          LocationFailure.permissionBlocked,
        ),
      };
    } on Object catch (error, stackTrace) {
      return _noPosition(
        'Could not ask for the location permission',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  LocationFailed _noPosition(
    String message, {
    required Object error,
    required StackTrace stackTrace,
  }) {
    _logger.error(_tag, message, error: error, stackTrace: stackTrace);
    return const LocationFailed(LocationFailure.noPosition);
  }

  Future<GeoPlace?> _placeAt(GeoPosition position, String locale) async {
    for (int attempt = 1; attempt <= placeAttempts; attempt++) {
      if (attempt > 1) await Future<void>.delayed(placeRetryDelay);
      try {
        final List<GeoPlace> places = await _location.placesAt(
          position,
          localeIdentifier: locale,
        );
        // An empty answer fails the attempt.
        if (places.isNotEmpty) return places.first;
        _logger.warning(
          _tag,
          'Place lookup failed (attempt $attempt of $placeAttempts)',
          error: 'no places',
        );
      } on Object catch (error, stackTrace) {
        _logger.warning(
          _tag,
          'Place lookup failed (attempt $attempt of $placeAttempts)',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    _logger.error(_tag, 'No place after $placeAttempts attempts');
    return null;
  }
}
