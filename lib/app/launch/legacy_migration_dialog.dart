import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/app/launch/launch_cubit.dart';
import 'package:one_second_diary/app/launch/launch_state.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/migrations/legacy_migration_report.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog.dart';
import 'package:one_second_diary/shared/widgets/progress/osd_progress_bar.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_tints.dart';

/// The pre-2023 Android folder migration, as one dialog that follows the
/// [LaunchCubit]: a progress bar while files move, then the outcome
/// (success, the old folders left behind, or the error with the manual
/// steps) with OK. It can't be dismissed; OK closes it at the end.
class LegacyMigrationDialog extends StatelessWidget {
  const LegacyMigrationDialog({super.key});

  static const Key progressKey = Key('legacyMigrationDialog.progress');
  static const Key okKey = Key('legacyMigrationDialog.ok');

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LaunchCubit, LaunchState>(
      builder: (BuildContext context, LaunchState state) {
        final LegacyMigrationReport? report = state.migrationReport;
        if (report == null && !state.migrationFailed) {
          return OsdDialog(
            title: Strings.migrationInProgress,
            body: Strings.doNotCloseTheApp,
            content: OsdProgressBar(
              key: progressKey,
              value: state.migrationTotal == 0
                  ? 0
                  : state.migrationDone / state.migrationTotal,
            ),
          );
        }
        final bool failed = report == null || !report.isComplete;
        return OsdDialog(
          badgeIcon: failed ? OsdIcons.error : OsdIcons.checkCircle,
          // A glyph on the sheet: GREEN_INK (GREEN is for dark surfaces).
          badgeColor: failed ? null : context.colors.greenInk,
          badgeTint: failed ? OsdTints.redTint12 : OsdTints.greenTint14,
          title: failed ? Strings.error : Strings.success,
          body: failed
              ? Strings.migrationError
              : report.oldFoldersRemoved
              ? Strings.migrationSuccess
              : Strings.migrationFolderDeletionError,
          actions: PrimaryButton(
            key: okKey,
            label: Strings.ok,
            onPressed: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }
}
