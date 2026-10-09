import 'dart:async';

import 'package:flutter/services.dart';
import 'package:one_second_diary/core/platform/orientation_sensor_gateway.dart';
import 'package:one_second_diary/core/platform/volume_key_gateway.dart';

/// The phone's motion sensor: [hold] turns the phone.
class FakeOrientationSensorGateway implements OrientationSensorGateway {
  final StreamController<DeviceOrientation?> _changes =
      StreamController<DeviceOrientation?>.broadcast();

  /// Whether the app listens to the sensor now (the camera page does).
  bool get listening => _changes.hasListener;

  /// The phone is now held in [orientation] (null: flat on a table).
  void hold(DeviceOrientation? orientation) => _changes.add(orientation);

  @override
  Stream<DeviceOrientation?> changes() => _changes.stream;

  Future<void> close() => _changes.close();
}

/// The hardware volume keys: [press] presses one.
class FakeVolumeKeyGateway implements VolumeKeyGateway {
  final StreamController<VolumeKey> _presses =
      StreamController<VolumeKey>.broadcast();

  /// Whether the app listens to the keys now (the camera page on Android).
  bool get listening => _presses.hasListener;

  void press(VolumeKey key) => _presses.add(key);

  @override
  Stream<VolumeKey> presses() => _presses.stream;

  Future<void> close() => _presses.close();
}
