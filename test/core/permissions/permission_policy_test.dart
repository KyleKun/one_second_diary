import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/permissions/permission_feature.dart';
import 'package:one_second_diary/core/permissions/permission_policy.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';

void main() {
  test('each feature asks for exactly the permissions it needs, by '
      'platform', () {
    // (feature, Android SDK level or null on iOS, permissions, why)
    final List<(PermissionFeature, int?, Set<AppPermission>, String)> rows = [
      (
        PermissionFeature.mediaLibrary,
        32,
        {AppPermission.storageLegacy},
        'Android 12 and older (SDK <= 32) need legacy storage',
      ),
      (
        PermissionFeature.mediaLibrary,
        33,
        {AppPermission.photos, AppPermission.videos},
        'Android 13 and newer (SDK >= 33) need photos and videos',
      ),
      (
        PermissionFeature.mediaLibrary,
        null,
        {},
        'iOS needs nothing: the diary lives in the app sandbox',
      ),
      (
        PermissionFeature.recording,
        34,
        {AppPermission.camera, AppPermission.microphone},
        'the in-app camera needs the camera and the microphone',
      ),
      (
        PermissionFeature.nativeCameraRecording,
        28,
        {AppPermission.camera},
        'the native camera app needs the camera only: it records the sound '
            'itself',
      ),
      (
        PermissionFeature.microphone,
        null,
        {AppPermission.microphone},
        'the microphone row of the permissions step asks the microphone '
            'alone',
      ),
      (
        PermissionFeature.geotagging,
        null,
        {AppPermission.location},
        'geotagging needs the location',
      ),
      (
        PermissionFeature.reminders,
        34,
        {AppPermission.notifications},
        'the daily reminder needs the notifications permission',
      ),
    ];

    for (final (feature, sdk, expected, why) in rows) {
      expect(
        PermissionPolicy.permissionsFor(feature, androidSdkInt: sdk),
        expected,
        reason: why,
      );
    }
  });
}
