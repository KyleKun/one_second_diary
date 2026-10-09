import 'package:equatable/equatable.dart';

/// A device position fix.
final class GeoPosition extends Equatable {
  const GeoPosition({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  List<Object?> get props => <Object?>[latitude, longitude];
}
