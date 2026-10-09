import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/identity/app_logo.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// What the reminder looks like: the app logo before the title over the
/// body. The text is the real notification's (`notificationTitle`,
/// `notificationBody`), the keys the reminders are planned with.
class NotificationPreviewTile extends StatelessWidget {
  const NotificationPreviewTile({super.key});

  static const Key surfaceKey = Key('notificationPreviewTile.surface');

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OsdSpace.pageGutter),
      child: DecoratedBox(
        key: surfaceKey,
        decoration: BoxDecoration(
          color: colors.c2,
          borderRadius: BorderRadius.circular(OsdRadius.r18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(OsdSpace.s14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: OsdSpace.s12,
            children: <Widget>[
              const AppLogo.preview(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: OsdSpace.s2,
                  children: <Widget>[
                    Text(
                      Strings.notificationTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.label14Strong.copyWith(
                        color: colors.tx,
                      ),
                    ),
                    Text(
                      Strings.notificationBody,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: typography.body14.copyWith(color: colors.d2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
