import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/android/check_release_manifest.dart';

/// The app's manifest as the release merge leaves it: what the recording
/// and player plugins add, and no `tools:` attributes (the merger applies
/// and drops them).
String _merged({String extra = ''}) =>
    File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+tools:\w+="[^"]*"'), '')
        .replaceFirst('<application', '''
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="com.kylekun.one_second_diary.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" />
    $extra
    <application''');

void main() {
  test('the app manifest, merged with its plugins, passes: CI and the '
      'manifest agree', () {
    expect(releaseManifestProblems(_merged()), isEmpty);
  });

  test('a plugin that brings INTERNET, an exact alarm or anything new fails '
      'the build, a foreground service and "Music and audio" included; so '
      'does a maxSdkVersion on WRITE_EXTERNAL_STORAGE (legacy storage '
      'installs could no longer save)', () {
    final List<String> problems = releaseManifestProblems(
      _merged(
        extra: '''
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.USE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />''',
      ),
    );

    expect(problems, hasLength(5));
    expect(problems[0], startsWith('forbidden android.permission.INTERNET'));
    expect(problems[1], startsWith('forbidden android.permission.USE_EXACT'));
    expect(
      problems[2],
      startsWith('unexpected android.permission.ACCESS_BACK'),
    );
    expect(problems[3], startsWith('unexpected android.permission.FOREGROUND'));
    expect(
      problems[4],
      startsWith('unexpected android.permission.READ_MEDIA_A'),
    );

    final String capped = _merged().replaceFirst(
      'android:name="android.permission.WRITE_EXTERNAL_STORAGE"',
      'android:name="android.permission.WRITE_EXTERNAL_STORAGE" '
          'android:maxSdkVersion="28"',
    );

    expect(releaseManifestProblems(capped), <Matcher>[
      startsWith('WRITE_EXTERNAL_STORAGE has a maxSdkVersion'),
    ]);
  });
}
