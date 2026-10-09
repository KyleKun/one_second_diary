import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:one_second_diary/core/platform/time_zone_gateway.dart';

/// [TimeZoneGateway] over `flutter_timezone`.
final class FlutterTimezoneGateway implements TimeZoneGateway {
  const FlutterTimezoneGateway();

  @override
  Future<String> localTimeZoneName() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;
}
