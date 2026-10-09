import 'package:flutter/services.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:one_second_diary/core/platform/orientation_sensor_gateway.dart';

/// [OrientationSensorGateway] over `native_device_orientation`, reading the
/// sensor (`useSensor: true`).
final class NativeOrientationSensorGateway implements OrientationSensorGateway {
  /// [sensorChanges] defaults to the plugin's sensor stream.
  NativeOrientationSensorGateway({
    Stream<NativeDeviceOrientation> Function()? sensorChanges,
  }) : _sensorChanges =
           sensorChanges ??
           (() => NativeDeviceOrientationCommunicator().onOrientationChanged(
             useSensor: true,
           ));

  final Stream<NativeDeviceOrientation> Function() _sensorChanges;

  @override
  Stream<DeviceOrientation?> changes() => _sensorChanges().map(
    (NativeDeviceOrientation orientation) => orientation.deviceOrientation,
  );
}
