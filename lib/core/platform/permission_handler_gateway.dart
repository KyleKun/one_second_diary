import 'package:flutter/foundation.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/platform/permission_gateway.dart';
import 'package:permission_handler/permission_handler.dart';

/// [PermissionGateway] over `permission_handler`.
///
/// iOS: the plugin builds under SwiftPM, where a permission is compiled in
/// only when its Info.plist usage key exists; a missing key reads as
/// permanently denied, never as a crash.
final class PermissionHandlerGateway implements PermissionGateway {
  PermissionHandlerGateway({required this._logger});

  final AppLogger _logger;

  static const String _tag = 'PERMISSIONS';

  @override
  Future<AppPermissionStatus> status(AppPermission permission) =>
      _orDenied('read the status of ${permission.name}', () async {
        return statusFrom(await pluginPermission(permission).status);
      });

  @override
  Future<AppPermissionStatus> request(AppPermission permission) =>
      _orDenied('request ${permission.name}', () async {
        return statusFrom(await pluginPermission(permission).request());
      });

  /// One plugin request for the whole group, so Android shows the group's
  /// prompts in one go (photos + videos, camera + microphone).
  @override
  Future<Map<AppPermission, AppPermissionStatus>> requestAll(
    Set<AppPermission> permissions,
  ) async {
    Map<Permission, PermissionStatus> results;
    try {
      results = await <Permission>[
        for (final AppPermission permission in permissions)
          pluginPermission(permission),
      ].request();
    } on Object catch (error, stackTrace) {
      _logFailure(
        'request ${permissions.map((AppPermission p) => p.name).join(' + ')}',
        error,
        stackTrace,
      );
      results = const <Permission, PermissionStatus>{};
    }
    return <AppPermission, AppPermissionStatus>{
      for (final AppPermission permission in permissions)
        permission: statusFrom(
          results[pluginPermission(permission)] ?? PermissionStatus.denied,
        ),
    };
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } on Object catch (error, stackTrace) {
      _logFailure('open the app settings', error, stackTrace);
      return false;
    }
  }

  /// [read], or [AppPermissionStatus.denied] (logged) when the plugin fails,
  /// as the interface says: never granted, never thrown.
  Future<AppPermissionStatus> _orDenied(
    String what,
    Future<AppPermissionStatus> Function() read,
  ) async {
    try {
      return await read();
    } on Object catch (error, stackTrace) {
      _logFailure(what, error, stackTrace);
      return AppPermissionStatus.denied;
    }
  }

  void _logFailure(String what, Object error, StackTrace stackTrace) => _logger
      .warning(_tag, 'Could not $what', error: error, stackTrace: stackTrace);

  /// The plugin permission behind [permission].
  @visibleForTesting
  static Permission pluginPermission(AppPermission permission) =>
      switch (permission) {
        AppPermission.camera => Permission.camera,
        AppPermission.microphone => Permission.microphone,
        AppPermission.storageLegacy => Permission.storage,
        AppPermission.photos => Permission.photos,
        AppPermission.videos => Permission.videos,
        // While in use only: the place is looked up while the editor is open.
        AppPermission.location => Permission.locationWhenInUse,
        AppPermission.notifications => Permission.notification,
      };

  /// `provisional` (iOS quiet notifications) counts as granted because the
  /// reminder is delivered. `limited` stays apart: the app needs full access.
  @visibleForTesting
  static AppPermissionStatus statusFrom(PermissionStatus status) =>
      switch (status) {
        PermissionStatus.granted ||
        PermissionStatus.provisional => AppPermissionStatus.granted,
        PermissionStatus.limited => AppPermissionStatus.limited,
        PermissionStatus.denied => AppPermissionStatus.denied,
        PermissionStatus.permanentlyDenied =>
          AppPermissionStatus.permanentlyDenied,
        PermissionStatus.restricted => AppPermissionStatus.restricted,
      };
}
