import 'package:flutter/services.dart';

/// How the phone is physically held, from its motion sensor
/// (`native_device_orientation` with `useSensor: true`), while the app's own
/// UI stays portrait.
abstract interface class OrientationSensorGateway {
  /// Each orientation the sensor reports while listened to; null when it
  /// can't tell (the phone lies flat). Raw: the debounce ("stable for N
  /// ms") and the lock live above this boundary, and the caller decides how
  /// a flat phone reads.
  Stream<DeviceOrientation?> changes();
}
