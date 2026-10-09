import 'package:one_second_diary/core/platform/pending_notification.dart';

import '../fakes/fake_notifications_gateway.dart';

/// A [FakeNotificationsGateway] whose OS delivers on time: once `clock`
/// reaches a notification's instant it is no longer [pending] but stays in
/// `scheduled` (in the shade) until cancelled, like a real notification.
class DeliveringNotificationsGateway extends FakeNotificationsGateway {
  DeliveringNotificationsGateway({required super.clock});

  /// Delivered and not cancelled: what the user sees in the shade.
  Iterable<ScheduledNotification> get shown => scheduled.values.where(
    (ScheduledNotification n) => !n.at.isAfter(clock.now()),
  );

  @override
  Future<List<PendingNotification>> pending() async => <PendingNotification>[
    for (final ScheduledNotification n in scheduled.values)
      if (n.at.isAfter(clock.now()))
        PendingNotification(id: n.id, title: n.title, body: n.body),
  ];
}
