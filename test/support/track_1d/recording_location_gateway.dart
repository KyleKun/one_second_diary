import 'package:one_second_diary/core/platform/geo_position.dart';

import '../fakes/fake_location_gateway.dart';

/// A [FakeLocationGateway] that also records the time limit of every fix
/// request, which the shared fake ignores.
class RecordingLocationGateway extends FakeLocationGateway {
  final List<Duration> timeLimits = <Duration>[];

  @override
  Future<GeoPosition> currentPosition({required Duration timeLimit}) {
    timeLimits.add(timeLimit);
    return super.currentPosition(timeLimit: timeLimit);
  }
}
