import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/wakelock_gateway.dart';

/// A [WakelockGateway] whose state is [enabled].
class FakeWakelockGateway extends Fake implements WakelockGateway {
  bool enabled = false;

  @override
  Future<void> enable() async {
    enabled = true;
  }

  @override
  Future<void> disable() async {
    enabled = false;
  }
}
