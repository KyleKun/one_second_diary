import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// A point on Earth, in degrees.
final class GeoPoint extends Equatable {
  const GeoPoint(this.lat, this.lon);

  final double lat;
  final double lon;

  static const double earthRadiusKm = 6371;

  /// The unit vector of this point: x towards 0°N 90°E, y the north pole,
  /// z towards 0°N 0°E.
  GlobeVector get vector {
    final double phi = radians(lat);
    final double lambda = radians(lon);
    return (
      x: math.cos(phi) * math.sin(lambda),
      y: math.sin(phi),
      z: math.cos(phi) * math.cos(lambda),
    );
  }

  static GeoPoint fromVector(GlobeVector v) {
    final double length = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    return GeoPoint(
      degrees(math.asin((v.y / length).clamp(-1.0, 1.0))),
      degrees(math.atan2(v.x, v.z)),
    );
  }

  /// The mean of [points] on the sphere; null when there are none.
  static GeoPoint? centroid(Iterable<GeoPoint> points) {
    double x = 0;
    double y = 0;
    double z = 0;
    int n = 0;
    for (final GeoPoint p in points) {
      final GlobeVector v = p.vector;
      x += v.x;
      y += v.y;
      z += v.z;
      n++;
    }
    if (n == 0 || (x == 0 && y == 0 && z == 0)) return null;
    return fromVector((x: x, y: y, z: z));
  }

  /// The central angle to [other], in radians.
  double angleTo(GeoPoint other) {
    final double dLat = radians(other.lat - lat);
    final double dLon = radians(other.lon - lon);
    final double a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(radians(lat)) *
            math.cos(radians(other.lat)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * math.asin(math.min(1, math.sqrt(a)));
  }

  double kmTo(GeoPoint other) => angleTo(other) * earthRadiusKm;

  /// The point [t] of the way along the great circle to [other].
  GeoPoint lerpTo(GeoPoint other, double t) =>
      fromVector(slerp(vector, other.vector, t));

  static double radians(double degrees) => degrees * math.pi / 180;

  static double degrees(double radians) => radians * 180 / math.pi;

  @override
  List<Object?> get props => <Object?>[lat, lon];
}

/// x right, y up, z towards the viewer in view space; see [GeoPoint.vector]
/// in world space.
typedef GlobeVector = ({double x, double y, double z});

GlobeVector slerp(GlobeVector a, GlobeVector b, double t) {
  final double dot = (a.x * b.x + a.y * b.y + a.z * b.z).clamp(-1.0, 1.0);
  final double omega = math.acos(dot);
  if (omega < 1e-6) return a;
  final double s = math.sin(omega);
  final double wa = math.sin((1 - t) * omega) / s;
  final double wb = math.sin(t * omega) / s;
  return (
    x: wa * a.x + wb * b.x,
    y: wa * a.y + wb * b.y,
    z: wa * a.z + wb * b.z,
  );
}
