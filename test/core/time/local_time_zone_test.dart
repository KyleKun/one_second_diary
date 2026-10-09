import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_time_zone.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../support/support.dart';
import '../../support/track_1d/fake_time_zone_gateway.dart';

void main() {
  late MemoryLogSink log;
  late FakeTimeZoneGateway gateway;
  late LocalTimeZone timeZone;

  setUp(() {
    log = MemoryLogSink();
    gateway = FakeTimeZoneGateway('Europe/Berlin');
    timeZone = LocalTimeZone(gateway: gateway, logger: memoryLogger(log));
  });

  test('sets tz.local to the device zone (v1.7 never set it, so reminders '
      'were planned in UTC)', () async {
    final tz.Location location = await timeZone.resolve();

    expect(location.name, 'Europe/Berlin');
    expect(tz.local.name, 'Europe/Berlin');
  });

  test('knows the old zone names phones still report (Asia/Calcutta, '
      'Europe/Kiev)', () async {
    gateway.name = 'Asia/Calcutta';
    expect((await timeZone.resolve()).name, 'Asia/Calcutta');
    gateway.name = 'Europe/Kiev';
    expect((await timeZone.resolve()).name, 'Europe/Kiev');
    expect(log.lines, isEmpty);
  });

  test('an unknown zone, or a platform failure, falls back to UTC with a '
      'warning', () async {
    gateway.name = 'Mars/Olympus_Mons';

    expect(await timeZone.resolve(), tz.UTC);
    expect(tz.local, tz.UTC);
    expect(
      log.lines.single,
      startsWith(
        '[WARNING] 2024-01-05 10:00:00.000: [NOTIFICATIONS] Unknown device '
        'time zone, reminders use UTC',
      ),
    );

    gateway.name = 'Europe/Berlin';
    expect((await timeZone.resolve()).name, 'Europe/Berlin');
    gateway.error = PlatformException(code: 'getLocalTimezone');

    expect(await timeZone.resolve(), tz.UTC);
    expect(tz.local, tz.UTC);
    expect(log.lines, hasLength(2));
    expect(log.lines.last, contains('reminders use UTC'));
  });
}
