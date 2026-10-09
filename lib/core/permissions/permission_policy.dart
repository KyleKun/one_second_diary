import 'package:one_second_diary/core/permissions/permission_feature.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';

/// Which permissions each [PermissionFeature] needs, by platform and
/// Android version. Asked for together, in one request per feature.
abstract final class PermissionPolicy {
  /// The permissions [feature] needs. [androidSdkInt] is
  /// `DeviceInfoGateway.androidSdkInt()`: null on iOS.
  static Set<AppPermission> permissionsFor(
    PermissionFeature feature, {
    required int? androidSdkInt,
  }) => switch (feature) {
    PermissionFeature.mediaLibrary => _mediaLibrary(androidSdkInt),
    PermissionFeature.recording => const <AppPermission>{
      AppPermission.camera,
      AppPermission.microphone,
    },
    // No microphone: the camera app records sound.
    PermissionFeature.nativeCameraRecording => const <AppPermission>{
      AppPermission.camera,
    },
    PermissionFeature.microphone => const <AppPermission>{
      AppPermission.microphone,
    },
    PermissionFeature.geotagging => const <AppPermission>{
      AppPermission.location,
    },
    PermissionFeature.reminders => const <AppPermission>{
      AppPermission.notifications,
    },
  };

  /// Android 13 (SDK 33) replaced the storage permission with per-media
  /// ones, and the app needs both images and videos granted. iOS keeps the
  /// diary in the app's own Documents folder, which needs no permission.
  static Set<AppPermission> _mediaLibrary(int? androidSdkInt) =>
      switch (androidSdkInt) {
        null => const <AppPermission>{},
        <= 32 => const <AppPermission>{AppPermission.storageLegacy},
        _ => const <AppPermission>{AppPermission.photos, AppPermission.videos},
      };
}
