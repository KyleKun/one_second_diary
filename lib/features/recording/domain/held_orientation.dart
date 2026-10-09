import 'dart:async';

import 'package:flutter/services.dart';
import 'package:one_second_diary/core/platform/orientation_sensor_gateway.dart';
import 'package:one_second_diary/features/recording/domain/recording_timing.dart';

/// How the phone is held, as the camera counts it: the first reading counts
/// at once, a change counts once the phone has stayed so for
/// [RecordingTiming.orientationSettle], and a flat phone keeps the way it was
/// held.
///
/// It reads the motion sensor apart from the camera's own events, so a slow
/// lens never holds the half second back. It listens only between [listen]
/// and [rest]; each way that counts goes to [onSettled].
final class HeldOrientation {
  HeldOrientation({required this._sensor, required this._onSettled});

  final OrientationSensorGateway _sensor;
  final void Function(DeviceOrientation orientation) _onSettled;

  StreamSubscription<DeviceOrientation?>? _readings;

  /// The way counted last; null until the first reading since [listen].
  DeviceOrientation? _settled;

  /// The way the phone was turned to, until it has stayed so long enough.
  Timer? _settling;

  /// Listens to the sensor, if it does not already; the first reading
  /// counts at once.
  void listen() {
    _readings ??= _sensor.changes().listen(_read);
  }

  /// Stops listening, and forgets a turn that had not settled yet.
  void rest() {
    _settling?.cancel();
    unawaited(_readings?.cancel());
    _readings = null;
    _settled = null;
  }

  void _read(DeviceOrientation? orientation) {
    if (orientation == null) return;
    _settling?.cancel();
    if (_settled == null) return _settle(orientation);
    if (orientation == _settled) return;
    _settling = Timer(
      RecordingTiming.orientationSettle,
      () => _settle(orientation),
    );
  }

  void _settle(DeviceOrientation orientation) {
    _settled = orientation;
    _onSettled(orientation);
  }
}
