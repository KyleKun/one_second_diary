import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';

/// The Settings pages' "Copy link" and "Copy address" snackbar actions.
abstract final class ClipboardFeedback {
  /// Copies [text] and says "Copied" in the nearest snackbar host.
  static Future<void> copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    OsdSnackbar.show(
      context,
      kind: OsdSnackKind.success,
      title: Strings.commonCopied,
    );
  }
}
