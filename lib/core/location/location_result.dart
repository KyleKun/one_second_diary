import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/platform/geo_position.dart';

/// The result of `LocationService.locate`.
sealed class LocationResult extends Equatable {
  const LocationResult();
}

/// The position and the place name to stamp ("City, Country").
final class LocationFound extends LocationResult {
  const LocationFound({required this.position, required this.placeName});

  /// Written to the clip's `location` tag with the place.
  final GeoPosition position;

  final String placeName;

  @override
  List<Object?> get props => <Object?>[position, placeName];
}

/// No place; the editor switches geotagging off and shows [failure].
final class LocationFailed extends LocationResult {
  const LocationFailed(this.failure);

  final LocationFailure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}

/// Why a location lookup gave no place. Each has its own state in the clip
/// editor's Location tab.
enum LocationFailure {
  /// The device's location service is off.
  serviceDisabled,

  /// The permission was refused; asking again can still work.
  permissionDenied,

  /// The permission can only be granted in Settings.
  permissionBlocked,

  /// No position fix within the time limit, or the platform failed while
  /// checking the service or asking for the permission.
  noPosition,

  /// A position but no place name: the geocoder needs the network, which
  /// is missing.
  offline,
}
