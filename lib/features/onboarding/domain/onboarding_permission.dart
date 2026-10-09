import 'package:one_second_diary/core/permissions/permission_feature.dart';

/// A row of the onboarding permissions step: one permission the app
/// uses, asked with its own "Allow", in this order.
///
/// Which rows a phone shows depends on its platform and Android version
/// ([shownOn]); the permissions behind a row follow `PermissionPolicy`.
/// Nothing is required: "Start my diary" goes on whatever was allowed.
enum OnboardingPermission {
  /// The gallery (Android only: `DCIM/OneSecondDiary`, where the diary
  /// lives). iOS keeps the diary in the app's own folder and needs nothing.
  gallery(PermissionFeature.mediaLibrary),

  /// The camera, alone: the in-app camera asks the microphone with it at
  /// the first record, but here each has its own row.
  camera(PermissionFeature.nativeCameraRecording),

  /// The microphone. Hidden where the system camera app records (below
  /// Android 10, or with "Force native camera" on), since it records the
  /// sound itself.
  microphone(PermissionFeature.microphone),

  /// Notifications, for the daily reminder. Hidden below Android 13, which
  /// always grants them.
  notifications(PermissionFeature.reminders),

  /// The location, for geotagging, which is off unless the user turns it
  /// on: the one row marked optional.
  location(PermissionFeature.geotagging, isOptional: true);

  const OnboardingPermission(this.feature, {this.isOptional = false});

  /// What the row asks for.
  final PermissionFeature feature;

  /// Whether the row says "Optional": the feature is off by default.
  final bool isOptional;

  /// Whether this row shows on a phone of [androidSdkInt] (null: iOS), with
  /// the "Force native camera" preference [forceNativeCamera].
  bool shownOn({
    required int? androidSdkInt,
    required bool forceNativeCamera,
  }) => switch (this) {
    gallery => androidSdkInt != null,
    camera || location => true,
    microphone =>
      androidSdkInt == null || (androidSdkInt >= 29 && !forceNativeCamera),
    notifications => androidSdkInt == null || androidSdkInt >= 33,
  };

  /// The rows a phone shows, in order.
  static List<OnboardingPermission> rowsFor({
    required int? androidSdkInt,
    required bool forceNativeCamera,
  }) => <OnboardingPermission>[
    for (final OnboardingPermission row in values)
      if (row.shownOn(
        androidSdkInt: androidSdkInt,
        forceNativeCamera: forceNativeCamera,
      ))
        row,
  ];
}
