// permission_handler compiles an iOS permission in only when its macro is
// on, and the project builds through CocoaPods, where the macros come from
// the Podfile. A permission left out answers "permanently denied" without
// ever showing the prompt.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/permissions/permission_feature.dart';
import 'package:one_second_diary/core/permissions/permission_policy.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';

/// The Info.plist usage description (none for notifications) and the
/// permission_handler macro behind each permission iOS can be asked for.
const Map<AppPermission, ({String? usageKey, String macro})> _ios = {
  AppPermission.camera: (
    usageKey: 'NSCameraUsageDescription',
    macro: 'PERMISSION_CAMERA',
  ),
  AppPermission.microphone: (
    usageKey: 'NSMicrophoneUsageDescription',
    macro: 'PERMISSION_MICROPHONE',
  ),
  AppPermission.photos: (
    usageKey: 'NSPhotoLibraryUsageDescription',
    macro: 'PERMISSION_PHOTOS',
  ),
  AppPermission.location: (
    usageKey: 'NSLocationWhenInUseUsageDescription',
    macro: 'PERMISSION_LOCATION_WHENINUSE',
  ),
  AppPermission.notifications: (
    usageKey: null,
    macro: 'PERMISSION_NOTIFICATIONS',
  ),
};

void main() {
  final String infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
  final String podfile = File('ios/Podfile').readAsStringSync();

  final Set<AppPermission> askedOnIOS = <AppPermission>{
    for (final PermissionFeature feature in PermissionFeature.values)
      ...PermissionPolicy.permissionsFor(feature, androidSdkInt: null),
  };

  test('iOS builds through CocoaPods on every machine, so the Podfile macros '
      'apply: under Swift Package Manager, the permission_handler_apple in '
      'pubspec.lock compiles every permission out', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();

    expect(
      pubspec,
      matches(
        RegExp(
          r'\nflutter:\n(?:[ \t].*\n|\n)*?  config:\n'
          r'(?:    .*\n)*?    enable-swift-package-manager: false\n',
        ),
      ),
    );
  });

  test('every permission iOS asks for has its usage description and its '
      'permission_handler macro for a CocoaPods build; the location prompt '
      'no longer promises that nothing leaves the phone: the place name is '
      'looked up by the system (D4)', () {
    expect(askedOnIOS, isNotEmpty);
    expect(_ios.keys, containsAll(askedOnIOS));
    for (final AppPermission permission in askedOnIOS) {
      final (:String? usageKey, :String macro) = _ios[permission]!;
      if (usageKey != null) {
        expect(
          infoPlist,
          matches(RegExp('<key>$usageKey</key>\\s*<string>[^<]+</string>')),
          reason: permission.name,
        );
      }
      expect(podfile, contains("'$macro=1'"), reason: permission.name);
    }

    final String prompt = RegExp(
      '<key>NSLocationWhenInUseUsageDescription</key>\\s*<string>([^<]+)',
    ).firstMatch(infoPlist)!.group(1)!;

    expect(prompt, isNot(contains('stays on your device')));
    expect(prompt, contains('location service'));
  });
}
