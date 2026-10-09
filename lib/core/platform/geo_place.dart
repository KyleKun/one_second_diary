import 'package:equatable/equatable.dart';

/// A reverse-geocoded place (the `geocoding` plugin's `Placemark` fields the
/// app uses). Empty strings from the plugin are reported as null.
final class GeoPlace extends Equatable {
  const GeoPlace({
    required this.locality,
    required this.subAdministrativeArea,
    required this.administrativeArea,
    required this.country,
  });

  /// City.
  final String? locality;

  /// County / district, the first fallback for the city.
  final String? subAdministrativeArea;

  /// State / region, the second fallback.
  final String? administrativeArea;

  final String? country;

  @override
  List<Object?> get props => <Object?>[
    locality,
    subAdministrativeArea,
    administrativeArea,
    country,
  ];
}
