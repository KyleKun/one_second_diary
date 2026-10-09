// The stores match an update to the installed app by its id; a different id
// would install a second app beside the user's diary.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('ProGuard keeps the ffmpeg-kit classes the JNI wrapper calls: a '
      'minified release build crashes on its first ffmpeg call without '
      'them', () {
    final String release = RegExp(
      r'buildTypes\s*\{\s*release\s*\{(.*?)\}',
      dotAll: true,
    ).firstMatch(_read('android/app/build.gradle'))!.group(1)!;

    expect(release, contains('minifyEnabled true'));
    expect(release, contains("'proguard-rules.pro'"));
    final String rules = _read('android/app/proguard-rules.pro');
    expect(
      rules,
      contains('-keep class com.antonkarpenko.ffmpegkit.** { *; }'),
    );
    expect(rules, contains('-keep class com.arthenica.ffmpegkit.** { *; }'));
  });

  test("the app keeps v1.7's identity: applicationId "
      'com.kylekun.one_second_diary, bundle com.kylekun.oneSecondDiary, and '
      'MainActivity on the volume-key activity (the shutter keys)', () {
    expect(
      _read('android/app/build.gradle'),
      contains('applicationId "com.kylekun.one_second_diary"'),
    );
    expect(
      _read('android/app/src/main/AndroidManifest.xml'),
      contains('android:name=".MainActivity"'),
    );
    expect(
      _read(
        'android/app/src/main/kotlin/com/kylekun/one_second_diary/'
        'MainActivity.kt',
      ),
      allOf(
        startsWith('package com.kylekun.one_second_diary\n'),
        contains('class MainActivity: FlutterAndroidVolumeKeydownActivity()'),
      ),
    );

    final Iterable<String> bundleIds =
        RegExp('PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
            .allMatches(_read('ios/Runner.xcodeproj/project.pbxproj'))
            .map((RegExpMatch match) => match.group(1)!);
    expect(bundleIds, isNotEmpty);
    expect(bundleIds, everyElement('com.kylekun.oneSecondDiary'));
  });
}
