import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/logging/bug_report_service.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_state.dart';
import 'package:one_second_diary/features/profiles/presentation/profile_labels.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog_action_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// A save that failed, with Close and "Report error". A phone out of space
/// says "Not enough storage" instead, with Close alone: there is nothing to
/// report.
///
/// Either button closes it: Close at once, "Report error" once the mail app
/// took the report (a spinner meanwhile, nothing dismisses it). The editor
/// stays as it was, so Save can be tried again.
class SaveFailedDialog extends StatefulWidget {
  const SaveFailedDialog({
    super.key,
    required this.failure,
    required this.photo,
    required this.onReport,
    this.shortfallBytes,
  });

  static const Key closeKey = Key('saveFailedDialog.close');

  static const Key reportKey = Key('saveFailedDialog.report');

  /// Shows the dialog; completes with how the report went when "Report
  /// error" was tapped, null when it was closed.
  static Future<BugReportOutcome?> show(
    BuildContext context, {
    required SaveFailure failure,
    required bool photo,
    required Future<BugReportOutcome> Function() onReport,
    int? shortfallBytes,
  }) => showOsdDialog<BugReportOutcome>(
    context,
    builder: (BuildContext context) => SaveFailedDialog(
      failure: failure,
      photo: photo,
      onReport: onReport,
      shortfallBytes: shortfallBytes,
    ),
  );

  final SaveFailure failure;

  /// Whether the source is a photo (the title says so).
  final bool photo;

  /// Opens the mail app with the logs (`BugReportService.reportError`).
  final Future<BugReportOutcome> Function() onReport;

  /// With [SaveFailure.outOfSpace]: the bytes to free when the storage
  /// budget refused the save before any work; null when the phone filled
  /// up while the clip was made.
  final int? shortfallBytes;

  @override
  State<SaveFailedDialog> createState() => _SaveFailedDialogState();
}

class _SaveFailedDialogState extends State<SaveFailedDialog> {
  bool _busy = false;

  Future<void> _report() async {
    if (_busy) return;
    setState(() => _busy = true);
    OsdDialogRoute.setBusy(context, busy: true);
    // BugReportService never throws: it falls back to a mailto link.
    final BugReportOutcome outcome = await widget.onReport();
    if (!mounted) return;
    OsdDialogRoute.setBusy(context, busy: false);
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final String closeLabel = CommonLabels.of(context).close;
    final String title = widget.photo
        ? Strings.savePhotoErrorTitle
        : Strings.saveVideoErrorTitle;
    return switch (widget.failure) {
      SaveFailure.outOfSpace => OsdDialog(
        badgeIcon: OsdIcons.error,
        title: title,
        // Refused by the storage budget before any work: how much to free; else the phone filled up while the clip was made.
        body: switch (widget.shortfallBytes) {
          final int shortfall => Strings.storageShort(
            amount: ProfileLabels.bytes(
              shortfall,
              format: LocaleFormats.of(context).numbers,
            ),
          ),
          null => Strings.notEnoughStorage,
        },
        actions: NeutralButton(
          key: SaveFailedDialog.closeKey,
          label: closeLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      SaveFailure.unexpected => OsdDialog(
        badgeIcon: OsdIcons.error,
        title: title,
        body: Strings.saveVideoErrorBody,
        actions: OsdDialogActionRow(
          cancel: NeutralButton(
            key: SaveFailedDialog.closeKey,
            label: closeLabel,
            size: OsdButtonSize.dense,
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
          confirm: PrimaryButton(
            key: SaveFailedDialog.reportKey,
            label: Strings.reportError,
            size: OsdButtonSize.dense,
            loading: _busy,
            onPressed: () => unawaited(_report()),
          ),
        ),
      ),
    };
  }
}
