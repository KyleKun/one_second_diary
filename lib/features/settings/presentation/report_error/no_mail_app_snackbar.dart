import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/logging/bug_report_service.dart';
import 'package:one_second_diary/features/settings/presentation/clipboard_feedback.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';

/// What every "Report error" and Contact says when no app on the phone
/// could open an email: "No email app found", "Write to {address}", with
/// "Copy address", in the nearest snackbar host.
abstract final class NoMailAppSnackbar {
  static void show(BuildContext context) => OsdSnackbar.show(
    context,
    kind: OsdSnackKind.error,
    title: Strings.contactNoEmailAppTitle,
    subtitle: Strings.contactNoEmailAppBody(
      address: BugReportService.developerEmail,
    ),
    actionLabel: Strings.contactCopyAddress,
    onAction: () =>
        ClipboardFeedback.copy(context, BugReportService.developerEmail),
  );
}
