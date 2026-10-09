import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/presentation/audio/mute_action_row.dart';
import 'package:one_second_diary/features/clips/presentation/privacy/privacy_action_row.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tags_action_row.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_action_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// What can be done to a saved clip from an Edit button (the viewer's, the
/// calendar's) and a Memories card's long press.
enum ClipAction {
  /// Edit its subtitles.
  subtitles,

  /// Edit its tags.
  tags,

  /// Mark it private, or public when it is private.
  privacy,

  /// Replace its sound with silence, for good.
  mute,

  /// Open the editor on its kept original recording.
  editAgain,

  /// Open a foreign clip in the editor to process it by hand.
  processImport,

  /// Hand its file to the system share sheet.
  share,

  /// Delete it for good.
  delete,
}

/// The one sheet of a clip's actions: the day as its title, then
/// Subtitles, Edit tags (with its "?"), Make private (Make public for a
/// private clip, with its "?"), Mute ("Muted", and nothing to tap, once it
/// is), Edit again (only with a kept original, [hasSource]), Process this
/// import (only for a foreign clip, [isForeign]), Share (only where no
/// button offers it, [withShare]: Memories) and Delete (in RED, last), as
/// the source sheets' action rows. It closes with the action tapped, or
/// null; who opened it runs the action once it has gone.
///
/// The viewer's Edit button opens it (dark, like the viewer); the
/// calendar's Edit button and a long press on a Memories card open it with
/// Share.
class ClipActionsSheet extends StatelessWidget {
  const ClipActionsSheet({
    super.key,
    required this.isPrivate,
    this.isMuted = false,
    this.hasSource = false,
    this.isForeign = false,
    this.withShare = true,
  });

  /// Whether the clip is private now.
  final bool isPrivate;

  /// Whether the clip is muted already.
  final bool isMuted;

  /// Whether the clip's original recording is kept (the Edit again row).
  final bool hasSource;

  /// Whether the clip is one the app did not make (the Process row).
  final bool isForeign;

  /// Whether Share is a row: not where a button beside the sheet's opener
  /// shares already (the viewer).
  final bool withShare;

  static const Key subtitlesKey = Key('clipActionsSheet.subtitles');
  static const Key tagsKey = Key('clipActionsSheet.tags');
  static const Key privacyKey = Key('clipActionsSheet.privacy');
  static const Key muteKey = Key('clipActionsSheet.mute');
  static const Key editAgainKey = Key('clipActionsSheet.editAgain');
  static const Key processImportKey = Key('clipActionsSheet.processImport');
  static const Key shareKey = Key('clipActionsSheet.share');
  static const Key deleteKey = Key('clipActionsSheet.delete');

  /// Shows the sheet titled [title] (the day, "Sunday, September 27") for
  /// a clip that [isPrivate] or not, [isMuted] or not, with a kept
  /// original ([hasSource]) or not and foreign ([isForeign]) or not, with
  /// a Share row ([withShare]) or not.
  static Future<ClipAction?> show(
    BuildContext context, {
    required String title,
    required bool isPrivate,
    bool isMuted = false,
    bool hasSource = false,
    bool isForeign = false,
    bool withShare = true,
  }) => showOsdSheet<ClipAction>(
    context,
    title: title,
    child: ClipActionsSheet(
      isPrivate: isPrivate,
      isMuted: isMuted,
      hasSource: hasSource,
      isForeign: isForeign,
      withShare: withShare,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: <Widget>[
        OsdActionRow(
          key: subtitlesKey,
          icon: OsdIcons.subtitles,
          label: Strings.subtitles,
          onTap: () => navigator.pop(ClipAction.subtitles),
        ),
        TagsActionRow(
          key: tagsKey,
          onTap: () => navigator.pop(ClipAction.tags),
        ),
        PrivacyActionRow(
          key: privacyKey,
          isPrivate: isPrivate,
          onTap: () => navigator.pop(ClipAction.privacy),
        ),
        MuteActionRow(
          key: muteKey,
          isMuted: isMuted,
          onTap: () => navigator.pop(ClipAction.mute),
        ),
        if (hasSource)
          OsdActionRow(
            key: editAgainKey,
            icon: OsdIcons.history,
            label: Strings.editAgain,
            onTap: () => navigator.pop(ClipAction.editAgain),
          ),
        if (isForeign)
          OsdActionRow(
            key: processImportKey,
            icon: OsdIcons.videoLibrary,
            label: Strings.clipProcessImport,
            onTap: () => navigator.pop(ClipAction.processImport),
          ),
        if (withShare)
          OsdActionRow(
            key: shareKey,
            icon: OsdIcons.share,
            label: Strings.share,
            onTap: () => navigator.pop(ClipAction.share),
          ),
        OsdActionRow(
          key: deleteKey,
          icon: OsdIcons.delete,
          label: CommonLabels.of(context).delete,
          tone: OsdActionRowTone.destructive,
          onTap: () => navigator.pop(ClipAction.delete),
        ),
      ],
    );
  }
}
