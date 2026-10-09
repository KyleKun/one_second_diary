import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/platform/player_state.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/audio/clip_mute_flow.dart';
import 'package:one_second_diary/features/clips/presentation/imports/process_import_flow.dart';
import 'package:one_second_diary/features/clips/presentation/originals/edit_again_flow.dart';
import 'package:one_second_diary/features/clips/presentation/privacy/clip_privacy_flow.dart';
import 'package:one_second_diary/features/clips/presentation/subtitles/subtitle_edit_flow.dart';
import 'package:one_second_diary/features/clips/presentation/tags/clip_tags_flow.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/viewer_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/viewer_state.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/features/diary/presentation/shown_clip_playback.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/clip_actions_sheet.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/delete_clip_dialog.dart';
import 'package:one_second_diary/shared/widgets/buttons/viewer_action_tile.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The two buttons at the end of the viewer's bottom row, beside the
/// caption: Share (the clip's file as it is stored; off while the clip
/// can't be played) and Edit, which opens the clip's other actions as one
/// sheet ([ClipActionsSheet], dark like the viewer): Subtitles, Edit tags,
/// Make private or public, Mute, Edit again (with a kept original),
/// Process this import (a foreign clip) and Delete. Each row runs the flow
/// its tile ran: the subtitles sheet through `SubtitleEditFlow`, the tags
/// sheet through `ClipTagsFlow`, `ClipPrivacyFlow`, `ClipMuteFlow` (which
/// asks first), `EditAgainFlow`, `ProcessImportFlow` and
/// [DeleteClipDialog] (then the viewer moves on). On a phone turned
/// sideways both are small glyph-only tiles ([compact]), so they cover
/// little of the video.
class ViewerActions extends StatelessWidget {
  const ViewerActions({
    super.key,
    required this.playback,
    this.compact = false,
  });

  /// Whether the buttons are the small glyph-only ones of a phone turned
  /// sideways, at the end of the row over the video.
  final bool compact;

  /// The Share button.
  static const Key shareKey = Key('viewerActions.share');

  /// The Edit button, which opens the sheet.
  static const Key moreKey = Key('viewerActions.more');

  /// The sheet's rows, where the tiles went (Edit opens the sheet first).
  static const Key subtitlesKey = ClipActionsSheet.subtitlesKey;
  static const Key tagsKey = ClipActionsSheet.tagsKey;
  static const Key privateKey = ClipActionsSheet.privacyKey;
  static const Key muteKey = ClipActionsSheet.muteKey;
  static const Key editAgainKey = ClipActionsSheet.editAgainKey;
  static const Key processImportKey = ClipActionsSheet.processImportKey;
  static const Key deleteKey = ClipActionsSheet.deleteKey;

  /// The gap between the two buttons.
  static const double _gap = 8;

  /// An upright button is at least this wide: the labels are short.
  static const double _minWidth = 72;

  /// The clip shown's player: Share waits while it can't play.
  final ShownClipPlayback playback;

  /// The sheet, then the action it closed with on the clip shown, once the
  /// sheet has gone (sheets and dialogs don't stack). The rows say the
  /// clip's state as the library knows it now.
  Future<void> _more(BuildContext context) async {
    final ViewerCubit cubit = context.read<ViewerCubit>();
    final ViewerState state = cubit.state;
    final ClipRef clip = state.clip;
    final ClipAction? action = await ClipActionsSheet.show(
      context,
      title: DiaryFormats.of(context).fullDate(clip.day),
      isPrivate: state.index?.isPrivate(clip) ?? false,
      isMuted: ClipMuteFlow.isMuted(context, clip),
      hasSource: state.index?.hasSource(clip) ?? false,
      isForeign: state.index?.isForeign(clip) ?? false,
      withShare: false,
    );
    if (action == null || !context.mounted) return;
    await Future<void>.delayed(OsdMotion.afterSheetClose);
    if (!context.mounted) return;
    switch (action) {
      case ClipAction.subtitles:
        await SubtitleEditFlow.edit(context, clip: clip);
      case ClipAction.tags:
        await ClipTagsFlow.edit(context, clip: clip);
      case ClipAction.privacy:
        await ClipPrivacyFlow.toggle(context, clip: clip);
      case ClipAction.mute:
        await ClipMuteFlow.mute(context, clip: clip);
      case ClipAction.editAgain:
        await EditAgainFlow.start(context, clip: clip);
      case ClipAction.processImport:
        await ProcessImportFlow.editOne(context, clip);
      case ClipAction.delete:
        await _delete(context);
      case ClipAction.share:
        return;
    }
  }

  /// A delete that left no clip closes the viewer once the dialog has gone,
  /// unless the viewer has closed already: the delete runs inside the
  /// dialog, so the viewer may not be the top route when it learns it has
  /// nothing left to show.
  Future<void> _delete(BuildContext context) async {
    final ViewerCubit cubit = context.read<ViewerCubit>();
    final ViewerState state = cubit.state;
    await DeleteClipDialog.show(
      context,
      clip: state.clip,
      profile: state.profile,
      several: state.dayPosition.count > 1,
      onDelete: cubit.deleteShown,
    );
    if (context.mounted &&
        cubit.state.closed &&
        (ModalRoute.isCurrentOf(context) ?? false)) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ViewerCubit cubit = context.read<ViewerCubit>();
    final List<Widget> buttons = <Widget>[
      ValueListenableBuilder<PlayerState?>(
        valueListenable: playback,
        builder: (BuildContext context, PlayerState? player, _) => Builder(
          builder: (BuildContext tile) => ViewerActionTile(
            key: shareKey,
            icon: OsdIcons.share,
            label: Strings.share,
            compact: compact,
            onPressed: player?.error != null
                ? null
                : () => unawaited(cubit.share(origin: _originOf(tile))),
          ),
        ),
      ),
      ViewerActionTile(
        key: moreKey,
        icon: OsdIcons.edit,
        label: Strings.edit,
        compact: compact,
        onPressed: () => unawaited(_more(context)),
      ),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: _gap,
      children: <Widget>[
        for (final Widget button in buttons)
          if (compact)
            button
          else
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: _minWidth),
              child: button,
            ),
      ],
    );
  }

  /// Where the button is on screen (the iPad share popover's anchor).
  static Rect? _originOf(BuildContext tile) {
    final RenderObject? box = tile.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}
