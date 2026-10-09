import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clips/presentation/subtitles/subtitle_sheet.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_info_card.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The Subtitles tab: one card with the subtitle of this clip. It opens
/// the shared `SubtitleSheet`; Save puts the text in the draft, any other
/// way out keeps the subtitle as it was.
class SubtitlesTab extends StatelessWidget {
  const SubtitlesTab({super.key});

  /// Opens the sheet on the subtitle of the editor around [context].
  static Future<void> edit(BuildContext context) async {
    final EditClipCubit editor = context.read<EditClipCubit>();
    final String? text = await SubtitleSheet.show(
      context,
      text: editor.state.draft.subtitles,
    );
    if (text == null || editor.isClosed) return;
    editor.subtitlesChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    final String subtitles = context.select(
      (EditClipCubit editor) => editor.state.draft.subtitles,
    );
    final OsdColors colors = context.colors;
    return OsdInfoCard(
      leading: OsdIcon(OsdIcons.subtitles, size: 22, color: colors.yellow),
      label: Strings.optionalLabel,
      value: subtitles.isEmpty ? Strings.addSubtitles : subtitles,
      valueMaxLines: 2,
      trailing: OsdIcon(OsdIcons.chevronRight, size: 22, color: colors.fa),
      onTap: () => unawaited(edit(context)),
    );
  }
}
