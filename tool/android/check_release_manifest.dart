// Checks the manifest of a release APK: what plugins merge in is invisible
// in android/app/src/main/AndroidManifest.xml, so CI runs this on the
// manifest of the release build (the android-build job in unit.yml).
// Run from the repository root:
//
//   dart run tool/android/check_release_manifest.dart <AndroidManifest.xml>
//
// The file is plain XML: the output of `apkanalyzer manifest print`, or the
// merged manifest under build/app/intermediates. It exits with 1 and lists
// every problem, or prints the permissions and exits with 0.
//
// Pure Dart, so it runs on the plain Dart VM.

import 'dart:io';

/// What the app itself uses. Every one must be in the release manifest.
const Set<String> requiredPermissions = {
  // The diary: videos and photos in DCIM, on every Android version, and
  // the legacy storage mode.
  'android.permission.READ_MEDIA_VIDEO',
  'android.permission.READ_MEDIA_IMAGES',
  'android.permission.READ_EXTERNAL_STORAGE',
  'android.permission.WRITE_EXTERNAL_STORAGE',
  'android.permission.ACCESS_MEDIA_LOCATION',
  // Recording (camera_android_camerax).
  'android.permission.CAMERA',
  'android.permission.RECORD_AUDIO',
  // Reminders: posted, re-armed after a reboot, inexact.
  'android.permission.POST_NOTIFICATIONS',
  'android.permission.RECEIVE_BOOT_COMPLETED',
  'android.permission.WAKE_LOCK',
  'android.permission.VIBRATE',
  // Geotagging, opt-in.
  'android.permission.ACCESS_FINE_LOCATION',
  'android.permission.ACCESS_COARSE_LOCATION',
};

/// What plugins merge in and the app accepts, present or not.
const Set<String> toleratedPermissions = {
  // media3 (video_player): a normal permission, no prompt.
  'android.permission.ACCESS_NETWORK_STATE',
};

/// androidx.core's app-private permission, `<applicationId>.<this>`.
const String dynamicReceiverPermission =
    'DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION';

/// Why a permission must never ship, for the ones that have a reason.
const Map<String, String> forbiddenPermissions = {
  'android.permission.INTERNET':
      'release builds have no network access (decision D11)',
  'android.permission.SCHEDULE_EXACT_ALARM':
      'reminders are inexact (decision D12)',
  'android.permission.USE_EXACT_ALARM': 'reminders are inexact (decision D12)',
};

/// The permissions [manifest] asks for, by name, each with its element
/// (`<uses-permission>` or `<uses-permission-sdk-23>`).
Map<String, String> declaredPermissions(String manifest) => {
  for (final RegExpMatch match in RegExp(
    r'<uses-permission(?:-sdk-23)?\b[^>]*>',
  ).allMatches(manifest))
    ?_attribute(match.group(0)!, 'android:name'): match.group(0)!,
};

String? _attribute(String element, String name) => RegExp(
  '${RegExp.escape(name)}\\s*=\\s*"([^"]*)"',
).firstMatch(element)?.group(1);

/// Every way [manifest] breaks the release rules; empty when it is fine.
List<String> releaseManifestProblems(String manifest) {
  final Map<String, String> declared = declaredPermissions(manifest);
  final List<String> problems = [
    for (final String permission in requiredPermissions)
      if (!declared.containsKey(permission)) 'missing $permission',
    for (final String permission in declared.keys)
      if (forbiddenPermissions[permission] case final String reason)
        'forbidden $permission: $reason'
      else if (!requiredPermissions.contains(permission) &&
          !toleratedPermissions.contains(permission) &&
          !permission.endsWith('.$dynamicReceiverPermission'))
        'unexpected $permission: review it, then list it in '
            'tool/android/check_release_manifest.dart',
  ];

  final String? write = declared['android.permission.WRITE_EXTERNAL_STORAGE'];
  if (write != null && _attribute(write, 'android:maxSdkVersion') != null) {
    problems.add(
      'WRITE_EXTERNAL_STORAGE has a maxSdkVersion: installs still in legacy '
      'storage mode could no longer save (tools:remove in the app manifest)',
    );
  }

  final String application =
      RegExp(r'<application\b[^>]*>').firstMatch(manifest)?.group(0) ?? '';
  for (final String flag in [
    'android:requestLegacyExternalStorage',
    'android:preserveLegacyExternalStorage',
  ]) {
    if (_attribute(application, flag) != 'true') {
      problems.add('<application> must keep $flag="true"');
    }
  }
  if (_attribute(application, 'android:usesCleartextTraffic') == 'true') {
    problems.add('<application> allows cleartext traffic (decision D11)');
  }

  final RegExpMatch? bootReceiver = RegExp(
    r'<receiver\b[^>]*ScheduledNotificationBootReceiver"[^>]*>(.*?)</receiver>',
    dotAll: true,
  ).firstMatch(manifest);
  if (bootReceiver == null ||
      !bootReceiver
          .group(1)!
          .contains('android.intent.action.BOOT_COMPLETED')) {
    problems.add(
      'the reminders boot receiver is missing: reminders would stop after a '
      'reboot (decision D12)',
    );
  }
  return problems;
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
      'usage: dart run tool/android/check_release_manifest.dart '
      '<AndroidManifest.xml>',
    );
    exit(64);
  }
  final String manifest = File(args.single).readAsStringSync();
  final List<String> problems = releaseManifestProblems(manifest);
  if (problems.isNotEmpty) {
    for (final String problem in problems) {
      stderr.writeln('::error::Release manifest: $problem');
    }
    exit(1);
  }
  final List<String> permissions = declaredPermissions(manifest).keys.toList()
    ..sort();
  stdout
    ..writeln('Release manifest OK. ${permissions.length} permissions:')
    ..writeAll(permissions.map((String p) => '  $p\n'));
}
