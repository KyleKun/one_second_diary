// The release build is the main manifest plus what plugins merge in; CI
// checks the merged result of a real release build
// (tool/android/check_release_manifest.dart).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _manifest(String build) =>
    File('android/app/src/$build/AndroidManifest.xml').readAsStringSync();

/// The `<uses-permission …>` elements of [manifest], by permission name.
Map<String, String> _permissions(String manifest) => <String, String>{
  for (final RegExpMatch match in RegExp(
    r'<uses-permission\b[^>]*?android:name="android\.permission\.(\w+)"[^>]*>',
    dotAll: true,
  ).allMatches(manifest))
    match.group(1)!: match.group(0)!,
};

/// The `<application …>` start tag of [manifest].
String _application(String manifest) => RegExp(
  '<application\\b[^>]*>',
  dotAll: true,
).firstMatch(manifest)!.group(0)!;

void main() {
  final String main = _manifest('main');

  test('the release build asks for exactly what the app uses: no network '
      '(no INTERNET, no cleartext traffic: decision D11) and no foreground '
      'service (O20)', () {
    expect(_application(main), isNot(contains('usesCleartextTraffic')));
    expect(_permissions(main).keys.toSet(), <String>{
      // The diary: videos (and photos) in DCIM, on every Android version.
      'READ_MEDIA_VIDEO',
      'READ_MEDIA_IMAGES',
      'READ_EXTERNAL_STORAGE',
      'WRITE_EXTERNAL_STORAGE',
      'ACCESS_MEDIA_LOCATION',
      // Reminders: posted, re-armed after a reboot, inexact. No
      // FOREGROUND_SERVICE: nothing runs as a foreground service.
      'POST_NOTIFICATIONS',
      'RECEIVE_BOOT_COMPLETED',
      'WAKE_LOCK',
      'VIBRATE',
      // Geotagging, opt-in.
      'ACCESS_FINE_LOCATION',
      'ACCESS_COARSE_LOCATION',
    });
  });

  test('debug and profile builds add INTERNET for the Flutter tool only; '
      'installs still in legacy storage mode keep writing to DCIM: '
      'WRITE_EXTERNAL_STORAGE has no maxSdkVersion, even the one a plugin '
      'merges in, and the legacy storage flags stay on (B_storage §3.7)', () {
    for (final String build in <String>['debug', 'profile']) {
      expect(_permissions(_manifest(build)).keys.toSet(), <String>{
        'INTERNET',
        'WRITE_EXTERNAL_STORAGE',
      }, reason: build);
    }

    final String write = _permissions(main)['WRITE_EXTERNAL_STORAGE']!;
    expect(write, contains('tools:remove="android:maxSdkVersion"'));
    expect(write, isNot(contains('android:maxSdkVersion=')));

    final String application = _application(main);
    expect(
      application,
      contains('android:requestLegacyExternalStorage="true"'),
    );
    expect(
      application,
      contains('android:preserveLegacyExternalStorage="true"'),
    );
  });
}
