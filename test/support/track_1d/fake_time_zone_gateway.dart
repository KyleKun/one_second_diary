import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/time_zone_gateway.dart';

/// A [TimeZoneGateway] that reports [name], or throws [error] when set.
class FakeTimeZoneGateway extends Fake implements TimeZoneGateway {
  FakeTimeZoneGateway(this.name);

  String name;
  Object? error;

  @override
  Future<String> localTimeZoneName() async {
    if (error case final Object error) throw error;
    return name;
  }
}
