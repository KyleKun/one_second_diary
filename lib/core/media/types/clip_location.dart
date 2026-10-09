import 'package:equatable/equatable.dart';

/// The geotag of a clip being saved.
///
/// With [enabled] the place [text] is burned in below the stamp and written
/// into the `location` metadata together with the coordinates. Coordinates
/// are never invented: a typed place name has none.
final class ClipLocation extends Equatable {
  const ClipLocation({
    required this.enabled,
    this.text,
    this.latitude,
    this.longitude,
  });

  const ClipLocation.off()
    : enabled = false,
      text = null,
      latitude = null,
      longitude = null;

  final bool enabled;

  /// Place name, e.g. `Tokyo, Japan` (geocoded or typed by the user).
  final String? text;

  final double? latitude;
  final double? longitude;

  @override
  List<Object?> get props => <Object?>[enabled, text, latitude, longitude];
}
