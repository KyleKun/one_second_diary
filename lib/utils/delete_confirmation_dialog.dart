import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'constants.dart';
import 'theme.dart';

/// "Are you sure?" before deleting something — a video or movie by default,
/// or whatever [titleKey]/[messageKey] describe. Pops with true when the user
/// confirms, false (or null, if dismissed) otherwise — the caller does the
/// actual deleting.
class DeleteConfirmationDialog extends StatelessWidget {
  const DeleteConfirmationDialog({
    super.key,
    this.titleKey = 'discardVideoTitle',
    this.messageKey = 'deleteVideoWarning',
  });

  /// Translation keys for the dialog's title and body.
  final String titleKey;
  final String messageKey;

  static Future<bool> show(
    BuildContext context, {
    String titleKey = 'discardVideoTitle',
    String messageKey = 'deleteVideoWarning',
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          DeleteConfirmationDialog(titleKey: titleKey, messageKey: messageKey),
    );
    return confirmed == true;
  }

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
                color: Colors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              titleKey.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              messageKey.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: mutedTextColor,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: textColor,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'no'.tr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        'yes'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
