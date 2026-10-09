import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/device_info_gateway.dart';

/// A [DeviceInfoGateway] reporting [sdkInt] (null = iOS).
class FakeDeviceInfoGateway extends Fake implements DeviceInfoGateway {
  FakeDeviceInfoGateway({this.sdkInt = 34});

  int? sdkInt;

  @override
  Future<int?> androidSdkInt() async => sdkInt;

  @override
  Future<String> description() async => sdkInt == null
      ? 'iOS 17.5, iPhone15,2'
      : 'Android 14 (SDK $sdkInt), Google Pixel 8';
}
