import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/notification_channel_text.dart';
import 'package:one_second_diary/core/platform/notification_tap.dart';
import 'package:one_second_diary/core/platform/notifications_gateway.dart';
import 'package:one_second_diary/core/platform/pending_notification.dart';

/// A notification scheduled on a [FakeNotificationsGateway].
final class ScheduledNotification extends Equatable {
  const ScheduledNotification({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.persistent,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final bool persistent;

  @override
  List<Object?> get props => <Object?>[id, at, title, body, persistent];
}

/// A [NotificationsGateway] that keeps the pending notifications as state.
///
/// [scheduled] holds what the OS would show, by id (scheduling an id again
/// replaces it); `cancel` / `cancelAll` remove entries. Like the real
/// gateway, an instant that is not after [clock]'s now is not scheduled; it
/// lands in [skipped] instead. [channel] is the Android channel's name and
/// description as the phone's settings show them. [tap] simulates the user
/// tapping a notification, and [tapsDelivered] counts the taps the app has
/// received. Call [close] in `tearDown`.
class FakeNotificationsGateway extends Fake implements NotificationsGateway {
  FakeNotificationsGateway({required this.clock});

  /// The "now" past instants are judged against.
  final Clock clock;

  final Map<int, ScheduledNotification> scheduled =
      <int, ScheduledNotification>{};

  /// Requests with an instant not after `clock.now()`, in call order.
  final List<ScheduledNotification> skipped = <ScheduledNotification>[];

  bool initialized = false;

  /// The Android channel's text; null until [initialize].
  NotificationChannelText? channel;

  /// Taps handed to the app's listeners so far (each listener counts).
  int tapsDelivered = 0;

  final StreamController<NotificationTap> _taps =
      StreamController<NotificationTap>.broadcast();

  void tap(int? id) => _taps.add(NotificationTap(id: id));

  Future<void> close() => _taps.close();

  @override
  Future<void> initialize({required NotificationChannelText channel}) async {
    initialized = true;
    this.channel = channel;
  }

  @override
  Future<void> updateChannel(NotificationChannelText channel) async {
    this.channel = channel;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required bool persistent,
  }) async {
    final ScheduledNotification notification = ScheduledNotification(
      id: id,
      at: at,
      title: title,
      body: body,
      persistent: persistent,
    );
    if (at.isAfter(clock.now())) {
      scheduled[id] = notification;
    } else {
      skipped.add(notification);
    }
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    scheduled.clear();
  }

  @override
  Future<List<PendingNotification>> pending() async => <PendingNotification>[
    for (final ScheduledNotification n in scheduled.values)
      PendingNotification(id: n.id, title: n.title, body: n.body),
  ];

  @override
  Stream<NotificationTap> get taps => _taps.stream.map((NotificationTap tap) {
    tapsDelivered++;
    return tap;
  });
}
