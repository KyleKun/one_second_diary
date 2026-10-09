import 'package:equatable/equatable.dart';

/// Which way a lens faces.
enum CameraFacing {
  /// The selfie lens (`recordWithFrontCamera: true`).
  front,

  /// The main lens.
  back,

  /// An external camera (a USB or Continuity camera).
  external,
}

/// What kind of lens a camera has, when the platform says (iOS does;
/// Android lists its cameras without it).
enum CameraLensKind {
  /// The main lens.
  wide,

  /// A wider view than the main lens.
  ultraWide,

  /// A closer view than the main lens.
  telephoto,

  unknown,
}

/// One camera of the phone, as the platform lists it.
final class CameraLens extends Equatable {
  const CameraLens({
    required this.id,
    required this.facing,
    required this.sensorOrientation,
    this.kind = CameraLensKind.unknown,
  });

  /// The platform's name for the lens (`CameraDescription.name`).
  final String id;
  final CameraFacing facing;

  /// Clockwise degrees (0, 90, 180, 270) the sensor's image is rotated from
  /// the phone's natural orientation.
  final int sensorOrientation;

  final CameraLensKind kind;

  @override
  List<Object?> get props => <Object?>[id, facing, sensorOrientation, kind];
}
