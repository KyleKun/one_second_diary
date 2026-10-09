import 'dart:async';

import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';

import '../../../support/support.dart';

/// A [FakePermissionGateway] whose system prompt stays up until the test
/// answers it ([answer]), like a user who reads it first.
class PendingPromptPermissionGateway extends FakePermissionGateway {
  // Made by the first prompt, in the zone the test runs the bloc in (fake
  // time), so its completion reaches the bloc there.
  Completer<void>? _prompt;

  /// The user answers the prompt (with [FakePermissionGateway.answers]).
  void answer() => _prompt?.complete();

  @override
  Future<Map<AppPermission, AppPermissionStatus>> requestAll(
    Set<AppPermission> permissions,
  ) async {
    await (_prompt ??= Completer<void>()).future;
    return super.requestAll(permissions);
  }
}
