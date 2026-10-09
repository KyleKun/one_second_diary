// flutter_local_notifications hears the notification center only through
// the app delegate: without it, iOS shows no reminder while the app is open
// and a tap never reaches a running app. The plugins are registered on the
// implicit engine (the UIScene life cycle), which must stay as it is.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final String delegate = File(
    'ios/Runner/AppDelegate.swift',
  ).readAsStringSync();

  /// The body of the Swift function whose signature starts with [start].
  String bodyOf(String start) {
    final int from = delegate.indexOf(start);
    expect(from, isNot(-1), reason: start);
    final int open = delegate.indexOf('{', from);
    int depth = 0;
    for (int i = open; i < delegate.length; i++) {
      if (delegate[i] == '{') depth++;
      if (delegate[i] == '}' && --depth == 0) {
        return delegate.substring(open + 1, i);
      }
    }
    fail('$start has no closing brace');
  }

  test('the app delegate becomes the notification center delegate at '
      'launch, before Flutter starts, and the plugins stay registered on '
      'the implicit engine', () {
    final String launch = bodyOf(
      'override func application(\n'
      '    _ application: UIApplication,\n'
      '    didFinishLaunchingWithOptions',
    );
    final int assigned = launch.indexOf(
      'UNUserNotificationCenter.current().delegate = self',
    );

    expect(assigned, isNot(-1));
    expect(
      assigned,
      lessThan(launch.indexOf('super.application(')),
      reason: 'set before the engine launches, so a launching tap is heard',
    );
    expect(
      delegate,
      contains(
        'class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate',
      ),
    );
    expect(
      bodyOf('func didInitializeImplicitFlutterEngine('),
      contains(
        'GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)',
      ),
    );
  });
}
