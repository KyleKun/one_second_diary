import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clips/data/clip_tags.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tags_sheet.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_info_card.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The General tab's tags card: how many tags this clip saves with ("3
/// tags", or "No tags yet"). It opens the shared `TagsSheet` with the
/// library's tags as suggestions; Save puts the list in the draft (nothing
/// is written until the clip is), any other way out keeps it as it was.
class TagsCard extends StatelessWidget {
  const TagsCard({super.key});

  static const Key cardKey = Key('tagsCard.card');

  /// Opens the sheet on the tags of the editor around [context].
  static Future<void> edit(BuildContext context) async {
    final EditClipCubit editor = context.read<EditClipCubit>();
    final ClipTags library = context.read<ClipTags>();
    final List<String>? tags = await TagsSheet.show(
      context,
      tags: editor.state.draft.tags,
      suggestions: <String>[
        for (final TagCount tag in library.vocabulary(
          profile: editor.state.draft.profile,
        ))
          tag.name,
      ],
    );
    if (tags == null || editor.isClosed) return;
    editor.tagsChanged(tags);
  }

  @override
  Widget build(BuildContext context) {
    final int count = context.select(
      (EditClipCubit editor) => editor.state.draft.tags.length,
    );
    final OsdColors colors = context.colors;
    return OsdInfoCard(
      key: cardKey,
      leading: OsdIcon(OsdIcons.sell, size: 22, color: colors.purple),
      label: Strings.tags,
      value: count == 0 ? Strings.tagsNoneYet : Strings.tagCount(count),
      valueMuted: count == 0,
      trailing: OsdIcon(OsdIcons.chevronRight, size: 22, color: colors.fa),
      onTap: () => unawaited(edit(context)),
    );
  }
}
