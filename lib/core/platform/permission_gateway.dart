import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';

/// Runtime permissions (`permission_handler`).
///
/// Which permissions a flow needs (the Android storage matrix by SDK level,
/// camera + microphone, the rationale loop) and when to ask is decided above
/// this boundary, in `lib/core/permissions/`; the gateway only maps
/// [AppPermission]s to the plugin. It is also the one way to ask for
/// notification permission ([AppPermission.notifications]).
///
/// Status mapping: `provisional` (iOS quiet notifications) reads as
/// [AppPermissionStatus.granted], because the reminder is delivered.
///
/// No call ever throws. A plugin failure (a broken channel, or Android's
/// "a request for permissions is already running") is logged by the
/// implementation and reads as [AppPermissionStatus.denied], so a flow asks
/// again later and never treats a failure as granted; [openSettings] then
/// returns false.
abstract interface class PermissionGateway {
  /// The current status, without prompting.
  Future<AppPermissionStatus> status(AppPermission permission);

  /// Shows the system prompt when the OS allows it and returns the result.
  Future<AppPermissionStatus> request(AppPermission permission);

  /// Asks for [permissions] in ONE system request (photos + videos on
  /// Android 13+, camera + microphone), so a denial is one prompt and one
  /// denial, not one per permission. Returns each one's result.
  Future<Map<AppPermission, AppPermissionStatus>> requestAll(
    Set<AppPermission> permissions,
  );

  /// Opens the app's page in the system Settings. Returns false when it
  /// could not be opened.
  Future<bool> openSettings();
}
