import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_avatar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/identity/profile_inline_text.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// "Delete this video?", then one line: the day (a clip of a day of
/// several: "This clip from …") and the [profile] it leaves, as a small
/// chip in the sentence; Cancel (focused
/// first) and a red Delete, which runs [onDelete] with the dialog waiting
/// (a spinner, nothing dismisses it). Opened from the calendar's caption
/// row and the viewer, whose dark theme it keeps.
abstract final class DeleteClipDialog {
  /// Asks before deleting [clip]; [several] when its day has other clips.
  static Future<void> show(
    BuildContext context, {
    required ClipRef clip,
    required Profile profile,
    required bool several,
    required Future<void> Function() onDelete,
  }) {
    final CommonLabels labels = CommonLabels.of(context);
    final String date = DiaryFormats.of(context).fullDate(clip.day);
    return OsdConfirmDialog.show(
      context,
      title: Strings.deleteVideoWarning,
      content: ProfileInlineText(
        text: several
            ? Strings.deleteClipBody(
                date: date,
                profile: ProfileInlineText.marker,
              )
            : Strings.deleteVideoBody(
                date: date,
                profile: ProfileInlineText.marker,
              ),
        name: profile.displayName,
        photo: ProfileAvatar.photoOf(context, profile),
      ),
      destructive: true,
      badgeIcon: OsdIcons.delete,
      cancelLabel: labels.cancel,
      confirmLabel: labels.delete,
      onConfirm: onDelete,
    );
  }
}
