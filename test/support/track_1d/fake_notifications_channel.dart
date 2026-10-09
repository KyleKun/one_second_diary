import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// The native side of `flutter_local_notifications`, faked at its method
/// channel, to test `LocalNotificationsGateway` on the host through the
/// plugin's real Dart code (argument mapping, platform dispatch, its own
/// "date in the future" check).
///
/// [install] makes the plugin run as on [platform] (Android or iOS) for the
/// current test and restores everything afterwards. [calls] records what
/// reached the OS, in order.
class FakeNotificationsChannel {
  FakeNotificationsChannel({this.platform = TargetPlatform.android});

  static const MethodChannel channel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  final TargetPlatform platform;

  final List<MethodCall> calls = <MethodCall>[];

  /// The answer to `getNotificationAppLaunchDetails` (null: no details).
  Map<String, Object?>? launchDetails;

  /// The answer to `pendingNotificationRequests`.
  List<Map<String, Object?>> pendingRequests = <Map<String, Object?>>[];

  /// The calls made with [method], in order.
  List<MethodCall> callsTo(String method) => <MethodCall>[
    for (final MethodCall call in calls)
      if (call.method == method) call,
  ];

  /// The arguments of the only call made with [method].
  Map<Object?, Object?> argumentsOf(String method) =>
      callsTo(method).single.arguments as Map<Object?, Object?>;

  void install() {
    final FlutterLocalNotificationsPlatform? original = _currentPlatform();
    debugDefaultTargetPlatformOverride = platform;
    switch (platform) {
      case TargetPlatform.iOS:
        IOSFlutterLocalNotificationsPlugin.registerWith();
      case _:
        AndroidFlutterLocalNotificationsPlugin.registerWith();
    }
    _messenger.setMockMethodCallHandler(channel, _answer);
    addTearDown(() {
      _messenger.setMockMethodCallHandler(channel, null);
      if (original != null) {
        FlutterLocalNotificationsPlatform.instance = original;
      }
      debugDefaultTargetPlatformOverride = null;
    });
  }

  /// The plugin's platform, or null while none is registered (its `late`
  /// field throws when read before, as in a host test).
  static FlutterLocalNotificationsPlatform? _currentPlatform() {
    try {
      return FlutterLocalNotificationsPlatform.instance;
    } on Error {
      return null;
    }
  }

  /// The OS reports a tap on notification [id] while the app runs.
  Future<void> tapFromOs(int id) async {
    await _messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('didReceiveNotificationResponse', <String, Object?>{
          'notificationId': id,
          'notificationResponseType': 0,
          'payload': '',
        }),
      ),
      (_) {},
    );
  }

  Future<Object?> _answer(MethodCall call) async {
    calls.add(call);
    return switch (call.method) {
      'initialize' => true,
      'getNotificationAppLaunchDetails' => launchDetails,
      'pendingNotificationRequests' => pendingRequests,
      _ => null,
    };
  }

  static TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
}
