import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/permissions/access_outcome.dart';
import 'package:one_second_diary/core/permissions/permission_feature.dart';
import 'package:one_second_diary/core/permissions/permission_policy.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/platform/device_info_gateway.dart';
import 'package:one_second_diary/core/platform/permission_gateway.dart';

/// Asks for what a [PermissionFeature] needs, following [PermissionPolicy]
/// and the just-in-time rules on [PermissionFeature].
///
/// The rationale loop is the calling cubit's state, never a callback into
/// the UI (dialogs follow state transitions through `BlocListener`):
/// 1. [request]; granted → go on.
/// 2. A refusal becomes state (e.g. `needsRationale(outcome)`), and the
///    screen shows the rationale sheet from it.
/// 3. "Allow access" on [AccessOutcome.denied] → [request] again (the
///    system prompt shows again). "Open settings" on
///    [AccessOutcome.blocked] → [openSettings], and the flow stops: the user
///    comes back and starts again. "Not now" keeps the refusal.
///
/// A plain class (not final), so cubit tests can fake it.
class PermissionRequester {
  PermissionRequester({
    required this._permissions,
    required this._deviceInfo,
    required this._logger,
  });

  final PermissionGateway _permissions;
  final DeviceInfoGateway _deviceInfo;
  final AppLogger _logger;

  /// The current state of [feature], without ever showing a prompt: the
  /// only call allowed at launch.
  Future<AccessOutcome> check(PermissionFeature feature) async =>
      AccessOutcome.of(<AppPermissionStatus>[
        for (final AppPermission permission in await _needed(feature))
          await _permissions.status(permission),
      ]);

  /// Asks for everything [feature] needs in one system request, and logs
  /// the answers. The OS shows no prompt for what is already granted or
  /// blocked. A feature that needs nothing is granted without asking.
  Future<AccessOutcome> request(PermissionFeature feature) async {
    final Set<AppPermission> needed = await _needed(feature);
    if (needed.isEmpty) return AccessOutcome.granted;
    final Map<AppPermission, AppPermissionStatus> statuses = await _permissions
        .requestAll(needed);
    final AccessOutcome outcome = AccessOutcome.of(statuses.values);
    final String answers = <String>[
      for (final MapEntry<AppPermission, AppPermissionStatus> entry
          in statuses.entries)
        '${entry.key.name} ${entry.value.name}',
    ].join(', ');
    _logger.info('PERMISSIONS', '${feature.name}: ${outcome.name} ($answers)');
    return outcome;
  }

  /// Opens the app's page in the system Settings (the "Open settings"
  /// action of a blocked state, step 3 of the loop above).
  Future<bool> openSettings() async {
    final bool opened = await _permissions.openSettings();
    if (!opened) _logger.warning('PERMISSIONS', 'Could not open Settings');
    return opened;
  }

  Future<Set<AppPermission>> _needed(PermissionFeature feature) async =>
      PermissionPolicy.permissionsFor(
        feature,
        androidSdkInt: await _deviceInfo.androidSdkInt(),
      );
}
