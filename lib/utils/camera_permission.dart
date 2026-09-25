import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import 'constants.dart';
import 'theme.dart';
import 'utils.dart';

/// Makes sure the app can record before anything tries to open the camera.
///
/// Called before navigating to the recording flow instead of letting the
/// camera fail to initialize, which only surfaced a generic "Error recording
/// video!" with no hint that a permission was the cause.
class CameraPermission {
  static const _logTag = '[CameraPermission] - ';

  /// Requests the camera (and, unless [requireMicrophone] is false, the
  /// microphone) and returns whether everything needed was granted.
  ///
  /// When something is denied, explains why it's needed and offers to ask
  /// again — or, once Android stops showing the system prompt (permanently
  /// denied), to open the app's settings page instead. Returns false in every
  /// case the caller can't record right now, including after sending the user
  /// to settings: they come back and tap record again.
  static Future<bool> ensureGranted({bool requireMicrophone = true}) async {
    final List<Permission> permissions = [
      Permission.camera,
      if (requireMicrophone) Permission.microphone,
    ];

    while (true) {
      final Map<Permission, PermissionStatus> statuses = await permissions
          .request();
      final Iterable<PermissionStatus> denied = statuses.values.where(
        (status) => !status.isGranted,
      );
      if (denied.isEmpty) return true;

      Utils.logWarning('${_logTag}Not granted: $statuses');

      final bool blocked = denied.any(
        (status) => status.isPermanentlyDenied || status.isRestricted,
      );
      final bool? primaryTapped = await Get.dialog<bool>(
        _CameraPermissionDialog(
          requireMicrophone: requireMicrophone,
          blocked: blocked,
        ),
      );

      if (primaryTapped != true) return false;
      if (blocked) {
        await openAppSettings();
        return false;
      }
      // Not blocked yet: loop and show the system prompt again.
    }
  }
}

class _CameraPermissionDialog extends StatelessWidget {
  const _CameraPermissionDialog({
    required this.requireMicrophone,
    required this.blocked,
  });

  final bool requireMicrophone;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeService().isDarkTheme();
    final Color textColor = isDark ? Colors.white : AppColors.dark;
    final Color mutedTextColor = isDark ? Colors.white70 : Colors.black54;

    return Dialog(
      backgroundColor: isDark ? AppColors.dark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.mainColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                requireMicrophone
                    ? Icons.videocam_rounded
                    : Icons.photo_camera_rounded,
                color: AppColors.mainColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              requireMicrophone
                  ? 'cameraMicPermissionTitle'.tr
                  : 'cameraPermissionTitle'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              requireMicrophone
                  ? 'cameraMicPermissionDesc'.tr
                  : 'cameraPermissionDesc'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: mutedTextColor,
              ),
            ),
            if (blocked) ...[
              const SizedBox(height: 12),
              Text(
                'permissionSettingsHint'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: mutedTextColor,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mainColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Get.back(result: true),
                child: Text(
                  blocked ? 'openSettings'.tr : 'allowAccess'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: mutedTextColor),
                onPressed: () => Get.back(result: false),
                child: Text('notNow'.tr, style: const TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
