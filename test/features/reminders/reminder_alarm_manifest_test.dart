// Pins the Android side of the reminders: without these entries scheduled
// reminders never fire or vanish at the next reboot, and an exact-alarm
// permission would contradict the inexact reminders the app schedules.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final String manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  /// The `<receiver …>…</receiver>` (or self-closing) element named [name].
  String? receiver(String name) => RegExp(
    '<receiver[^>]*android:name="${RegExp.escape(name)}"'
    '[^>]*?(/>|>.*?</receiver>)',
    dotAll: true,
  ).firstMatch(manifest)?.group(0);

  test('declares the plugin receiver that shows scheduled reminders, and the '
      'boot receiver with its permission that re-arms them after a reboot or '
      'an app update (v1.7 had only the permission)', () {
    final String? shows = receiver(
      'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
    );

    expect(shows, isNotNull);
    expect(shows, contains('android:exported="false"'));

    final String? element = receiver(
      'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver',
    );

    expect(element, isNotNull);
    expect(element, contains('android:exported="false"'));
    for (final String action in <String>[
      'android.intent.action.BOOT_COMPLETED',
      'android.intent.action.MY_PACKAGE_REPLACED',
      'android.intent.action.QUICKBOOT_POWERON',
      'com.htc.intent.action.QUICKBOOT_POWERON',
    ]) {
      expect(element, contains('<action android:name="$action"'));
    }
    expect(
      manifest,
      contains(
        '<uses-permission android:name='
        '"android.permission.RECEIVE_BOOT_COMPLETED"',
      ),
    );
  });

  test('asks for no exact-alarm permission, in any build, and never '
      'schedules an exact alarm (decision D12)', () {
    for (final String build in <String>['main', 'debug', 'profile']) {
      final String text = File(
        'android/app/src/$build/AndroidManifest.xml',
      ).readAsStringSync();
      for (final String permission in <String>[
        'SCHEDULE_EXACT_ALARM',
        'USE_EXACT_ALARM',
      ]) {
        expect(
          text,
          isNot(contains('android:name="android.permission.$permission"')),
          reason: '$build manifest',
        );
      }
    }

    // Without the permission, Android 12+ throws on an exact alarm.
    final List<String> exact = <String>[
      for (final FileSystemEntity file in Directory(
        'lib',
      ).listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            !file.uri.pathSegments.last.startsWith('._') &&
            RegExp(
              r'AndroidScheduleMode\.(exact|alarmClock)',
            ).hasMatch(file.readAsStringSync()))
          file.path,
    ];

    expect(exact, isEmpty);
  });
}
