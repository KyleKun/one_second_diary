import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/presentation/audio/mute_action_row.dart';
import 'package:one_second_diary/features/clips/presentation/privacy/privacy_action_row.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tags_action_row.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_action_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// What the Edit sheet can do with the clip in view.
enum TodayEditAction {
  /// Record the day's second again, in place of this clip.
  recordAgain,

  /// Pick a video from the gallery, in place of this clip.
  replaceFromGallery,

  /// Open the editor on the clip's kept original recording, pre-filled; offered only when the clip has one.
  editAgain,

  /// Edit the clip's subtitle.
  editSubtitles,

  /// Mark the clip private, or public when it is private.
  togglePrivate,

  /// Replace the clip's sound with silence, for good (offered once).
  mute,

  /// Edit the clip's tags.
  editTags,

  /// Delete the clip (the page asks first).
  delete,
}

/// Today's Edit sheet: a saved clip's trim and stamp can't be edited again
/// once its source is gone, so Edit offers to replace it, from the camera
/// or the gallery; when the original recording is kept ([canEditAgain]) it offers "Edit again" on it first; then to
/// edit its subtitle, to make it private (public, when it is private; its
/// "?" beside it), to mute it ("Muted", and nothing to tap, once it is) or
/// to edit its tags (with their "?"); and, at the end, to delete it.
class TodayEditSheet extends StatelessWidget {
  const TodayEditSheet({
    super.key,
    required this.isPrivate,
    this.isMuted = false,
    this.canEditAgain = false,
  });

  /// Whether the clip in view is private now.
  final bool isPrivate;

  /// Whether the clip in view is muted already.
  final bool isMuted;

  /// Whether the clip in view has a kept original recording.
  final bool canEditAgain;

  static const Key bodyKey = Key('todayEditSheet.body');

  static Key rowKey(TodayEditAction action) =>
      ValueKey<String>('todayEditSheet.${action.name}');

  /// Opens the sheet for a clip that [isPrivate] or not and [isMuted] or
  /// not; completes with the action tapped, or null when it is closed.
  static Future<TodayEditAction?> show(
    BuildContext context, {
    required bool isPrivate,
    bool isMuted = false,
    bool canEditAgain = false,
  }) => showOsdSheet<TodayEditAction>(
    context,
    title: Strings.todayEditSheetTitle,
    child: TodayEditSheet(
      key: bodyKey,
      isPrivate: isPrivate,
      isMuted: isMuted,
      canEditAgain: canEditAgain,
    ),
  );

  @override
  Widget build(BuildContext context) {
    void pick(TodayEditAction action) => Navigator.of(context).pop(action);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.s8,
      children: <Widget>[
        if (canEditAgain)
          OsdActionRow(
            key: rowKey(TodayEditAction.editAgain),
            icon: OsdIcons.history,
            label: Strings.editAgain,
            tone: OsdActionRowTone.primary,
            onTap: () => pick(TodayEditAction.editAgain),
          ),
        OsdActionRow(
          key: rowKey(TodayEditAction.recordAgain),
          icon: OsdIcons.videocam,
          label: Strings.recordAgain,
          tone: OsdActionRowTone.primary,
          onTap: () => pick(TodayEditAction.recordAgain),
        ),
        OsdActionRow(
          key: rowKey(TodayEditAction.replaceFromGallery),
          icon: OsdIcons.videoLibrary,
          label: Strings.replaceFromGallery,
          onTap: () => pick(TodayEditAction.replaceFromGallery),
        ),
        OsdActionRow(
          key: rowKey(TodayEditAction.editSubtitles),
          icon: OsdIcons.subtitles,
          label: Strings.editSubtitles,
          onTap: () => pick(TodayEditAction.editSubtitles),
        ),
        PrivacyActionRow(
          key: rowKey(TodayEditAction.togglePrivate),
          isPrivate: isPrivate,
          onTap: () => pick(TodayEditAction.togglePrivate),
        ),
        MuteActionRow(
          key: rowKey(TodayEditAction.mute),
          isMuted: isMuted,
          onTap: () => pick(TodayEditAction.mute),
        ),
        TagsActionRow(
          key: rowKey(TodayEditAction.editTags),
          onTap: () => pick(TodayEditAction.editTags),
        ),
        OsdActionRow(
          key: rowKey(TodayEditAction.delete),
          icon: OsdIcons.delete,
          label: CommonLabels.of(context).delete,
          tone: OsdActionRowTone.destructive,
          onTap: () => pick(TodayEditAction.delete),
        ),
      ],
    );
  }
}
