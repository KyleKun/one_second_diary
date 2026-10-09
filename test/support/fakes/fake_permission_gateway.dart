import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/platform/permission_gateway.dart';

/// A [PermissionGateway] with scripted answers.
///
/// [statuses] is the current state (missing = denied). `request` behaves like
/// the OS: a granted or blocked permission is returned without a prompt;
/// otherwise the "user" answers with [answers] (missing = granted) and the
/// answer becomes the new status. `requestAll` answers each permission the
/// same way. [requested] (single requests), [requestedTogether] (grouped
/// requests) and [settingsOpened] record what the code under test did.
class FakePermissionGateway extends Fake implements PermissionGateway {
  final Map<AppPermission, AppPermissionStatus> statuses =
      <AppPermission, AppPermissionStatus>{};
  final Map<AppPermission, AppPermissionStatus> answers =
      <AppPermission, AppPermissionStatus>{};
  final List<AppPermission> requested = <AppPermission>[];
  final List<Set<AppPermission>> requestedTogether = <Set<AppPermission>>[];
  bool settingsOpened = false;
  bool openSettingsResult = true;

  @override
  Future<AppPermissionStatus> status(AppPermission permission) async =>
      statuses[permission] ?? AppPermissionStatus.denied;

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async {
    requested.add(permission);
    return _prompt(permission);
  }

  @override
  Future<Map<AppPermission, AppPermissionStatus>> requestAll(
    Set<AppPermission> permissions,
  ) async {
    requestedTogether.add(Set<AppPermission>.unmodifiable(permissions));
    return <AppPermission, AppPermissionStatus>{
      for (final AppPermission permission in permissions)
        permission: await _prompt(permission),
    };
  }

  Future<AppPermissionStatus> _prompt(AppPermission permission) async {
    final AppPermissionStatus current = await status(permission);
    if (current.isGranted || current.isBlocked) return current;
    final AppPermissionStatus answer =
        answers[permission] ?? AppPermissionStatus.granted;
    statuses[permission] = answer;
    return answer;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened = true;
    return openSettingsResult;
  }
}
