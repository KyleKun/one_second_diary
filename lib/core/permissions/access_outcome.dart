import 'package:one_second_diary/core/platform/app_permission_status.dart';

/// Whether a feature can use everything it needs, and if not, whether asking
/// again can help. The screen picks its copy and action from it: "Allow
/// access" (asks again) for [denied], "Open settings" for [blocked].
enum AccessOutcome {
  /// Every permission is granted.
  granted,

  /// Something is missing, and the system prompt can still be shown (this
  /// includes `limited` partial access, which is not enough).
  denied,

  /// Something is permanently denied or restricted: only the system
  /// Settings page can grant it.
  blocked;

  /// The outcome of a group: granted only when every one is, blocked as
  /// soon as one is blocked.
  static AccessOutcome of(Iterable<AppPermissionStatus> statuses) {
    if (statuses.every((AppPermissionStatus s) => s.isGranted)) return granted;
    if (statuses.any((AppPermissionStatus s) => s.isBlocked)) return blocked;
    return denied;
  }
}
