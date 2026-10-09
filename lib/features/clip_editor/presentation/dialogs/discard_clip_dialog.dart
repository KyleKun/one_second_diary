import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/buttons/destructive_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog_action_row.dart';

/// How the user left the discard dialog, when not by "Keep editing".
enum DiscardChoice {
  /// Leave without the clip.
  discard,

  /// Record the clip again (a recording only).
  recordAgain,
}

/// Asks before the clip editor is left without saving: "Keep editing"
/// (focused first) or "Discard", and for a recording "Record again".
class DiscardClipDialog extends StatelessWidget {
  const DiscardClipDialog({
    super.key,
    required this.recordAgain,
    required this.photo,
  });

  static const Key keepKey = Key('discardClipDialog.keep');

  static const Key discardKey = Key('discardClipDialog.discard');

  static const Key recordAgainKey = Key('discardClipDialog.recordAgain');

  /// Shows the dialog; completes with the choice, or null for "Keep
  /// editing" (the scrim and back too).
  static Future<DiscardChoice?> show(
    BuildContext context, {
    required bool recordAgain,
    required bool photo,
  }) => showOsdDialog<DiscardChoice>(
    context,
    builder: (BuildContext context) =>
        DiscardClipDialog(recordAgain: recordAgain, photo: photo),
  );

  /// Whether "Record again" is offered.
  final bool recordAgain;

  /// Whether the source is a photo (the title says so).
  final bool photo;

  @override
  Widget build(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    final Widget row = OsdDialogActionRow(
      cancel: NeutralButton(
        key: keepKey,
        label: Strings.keepEditing,
        size: OsdButtonSize.dense,
        autofocus: true,
        onPressed: navigator.pop,
      ),
      confirm: DestructiveButton(
        key: discardKey,
        label: Strings.discard,
        onPressed: () => navigator.pop(DiscardChoice.discard),
      ),
    );
    return OsdDialog(
      title: photo ? Strings.discardPhotoTitle : Strings.discardVideoTitle,
      body: Strings.discardVideoBody,
      actions: recordAgain
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: <Widget>[
                row,
                OsdTextButton(
                  key: recordAgainKey,
                  label: Strings.recordAgain,
                  tone: OsdTextButtonTone.muted,
                  onPressed: () => navigator.pop(DiscardChoice.recordAgain),
                ),
              ],
            )
          : row,
    );
  }
}
