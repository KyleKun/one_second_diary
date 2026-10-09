// App Store Connect rejects an upload whose code calls a required-reason API
// that no manifest declares; the plugins declare their own, the Runner's
// covers the app's code and the plugins that ship none (ffmpeg-kit's stat
// calls, flutter_archive's file dates, device_info_plus's free space).
// Nothing leaves the phone, so it declares no tracking and no collected data.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final String manifest = File(
    'ios/Runner/PrivacyInfo.xcprivacy',
  ).readAsStringSync();

  test('the Runner target bundles the privacy manifest: no tracking, no '
      'collected data, and each required-reason API the app reaches has its '
      'reason', () {
    final String project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final String resources = RegExp(
      r'isa = PBXResourcesBuildPhase;.*?files = \(([^)]*)\)',
      dotAll: true,
    ).firstMatch(project)!.group(1)!;

    expect(resources, contains('PrivacyInfo.xcprivacy in Resources'));
    expect(project, contains('path = PrivacyInfo.xcprivacy;'));

    expect(
      manifest,
      matches(RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>')),
    );
    expect(
      manifest,
      matches(RegExp(r'<key>NSPrivacyTrackingDomains</key>\s*<array/>')),
    );
    expect(
      manifest,
      matches(RegExp(r'<key>NSPrivacyCollectedDataTypes</key>\s*<array/>')),
    );

    final Map<String, List<String>> declared = <String, List<String>>{
      for (final RegExpMatch match in RegExp(
        r'NSPrivacyAccessedAPICategory(\w+)</string>\s*'
        r'<key>NSPrivacyAccessedAPITypeReasons</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).allMatches(manifest))
        match.group(1)!: <String>[
          for (final RegExpMatch reason in RegExp(
            '<string>([^<]+)</string>',
          ).allMatches(match.group(2)!))
            reason.group(1)!,
        ],
    };

    expect(declared, <String, List<String>>{
      // shared_preferences: the app's own settings.
      'UserDefaults': <String>['CA92.1'],
      // Clip, cache and scratch file dates, all inside the app container.
      'FileTimestamp': <String>['C617.1'],
      // The free-space check before a movie is made.
      'DiskSpace': <String>['E174.1'],
    });
  });
}
