import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tag_filter_sheet.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tags_help_button.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/shared/widgets/controls/tag_chip_row.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/shared/widgets/surfaces/section_label.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// Create movie's "Tags": "Only videos tagged…" and "Leave out videos tagged…",
/// each opening the tag sheet over the profile's vocabulary and showing the
/// tags chosen ("Any tag" and "—" when none), the chosen tags as chips under
/// them (the × removes one), and the "?" that explains tags.
class MovieTagsCard extends StatelessWidget {
  const MovieTagsCard({super.key});

  static const Key cardKey = Key('movieTagsCard.card');
  static const Key onlyTaggedKey = Key('movieTagsCard.onlyTagged');
  static const Key withoutTaggedKey = Key('movieTagsCard.withoutTagged');
  static const Key chipsKey = Key('movieTagsCard.chips');

  @override
  Widget build(BuildContext context) {
    final ({bool hasTags, TagFilter tags}) flow = context
        .select<CreateMovieCubit, ({bool hasTags, TagFilter tags})>(
          (CreateMovieCubit flow) => (
            hasTags: flow.state.index?.hasTags ?? false,
            tags: flow.state.tags,
          ),
        );
    if (!flow.hasTags) return const SizedBox.shrink();
    final OsdColors colors = context.colors;
    final TagFilter tags = flow.tags;
    final List<String> chosen = <String>[...tags.anyOf, ...tags.noneOf];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: SectionLabel.icon(
                label: Strings.movieTagsSection,
                icon: OsdIcons.sell,
                iconColor: colors.purple,
                padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 8, 8),
              ),
            ),
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 12, top: 10),
              child: TagsHelpButton(),
            ),
          ],
        ),
        OsdCard(
          key: cardKey,
          child: Column(
            children: <Widget>[
              OsdListRow(
                key: onlyTaggedKey,
                icon: OsdIcons.sell,
                title: Strings.movieOnlyTagged,
                value: tags.anyOf.isEmpty
                    ? Strings.movieTagsAny
                    : MovieLabels.tagList(context, tags.anyOf),
                trailing: const OsdRowTrailing.chevron(),
                onTap: () => unawaited(_pickOnly(context, tags)),
              ),
              const OsdDivider(),
              OsdListRow(
                key: withoutTaggedKey,
                icon: OsdIcons.filterList,
                title: Strings.movieWithoutTagged,
                value: tags.noneOf.isEmpty
                    ? '—'
                    : MovieLabels.tagList(context, tags.noneOf),
                trailing: const OsdRowTrailing.chevron(),
                onTap: () => unawaited(_pickWithout(context, tags)),
              ),
              if (chosen.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 16, 14),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TagChipRow(
                      key: chipsKey,
                      tags: chosen,
                      colorOf: context.read<TagColors>().colorOf,
                      onTap: context.read<CreateMovieCubit>().removeTag,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickOnly(BuildContext context, TagFilter tags) async {
    final CreateMovieCubit flow = context.read<CreateMovieCubit>();
    final Set<String>? picked = await TagFilterSheet.show(
      context,
      title: Strings.movieOnlyTagged,
      tags: _vocabulary(flow),
      initial: tags.anyOf,
      searchHint: Strings.diarySearchHint,
    );
    if (picked != null) flow.setOnlyTags(picked);
  }

  Future<void> _pickWithout(BuildContext context, TagFilter tags) async {
    final CreateMovieCubit flow = context.read<CreateMovieCubit>();
    final Set<String>? picked = await TagFilterSheet.show(
      context,
      title: Strings.movieWithoutTagged,
      tags: _vocabulary(flow),
      initial: tags.noneOf,
      searchHint: Strings.diarySearchHint,
    );
    if (picked != null) flow.setWithoutTags(picked);
  }

  /// The profile's tags with their counts, of every clip (the sheet is
  /// about what to keep or drop, not about what is left).
  static List<TagCount> _vocabulary(CreateMovieCubit flow) =>
      flow.state.index?.tagCounts ?? const <TagCount>[];
}
