import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/diary/domain/clip_filter.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/features/diary/presentation/sheets/diary_filter_sheet.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/controls/tag_chip.dart';
import 'package:one_second_diary/shared/widgets/controls/view_toggle.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_text_swap.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The Diary's title row: "Calendar" or "Memories" in the display face
/// (one line that scales down to fit), the filter button (a dot on it
/// while a filter is on) and the view toggle. The toggle lays out 48 tall
/// (its targets), so the design's 12 / 6 padding around its 40 px track is
/// 8 / 2 here.
///
/// A switch changes the title letter by letter (`OsdTextSwap`). The design
/// system's `OsdDisplayTitle` draws a fixed title, so the Diary draws its
/// own with the same style.
///
/// Under the row, while a filter is on, what it keeps ([_FilterSummary]):
/// the chosen tags, "Without tags" and the search as chips (tapping one
/// lets it go), "N videos match" and Clear.
class DiaryTitleRow extends StatelessWidget {
  const DiaryTitleRow({super.key});

  static const Key titleKey = Key('diaryTitleRow.title');

  /// The filter button.
  static const Key filterKey = Key('diaryTitleRow.filter');

  /// The dot on the filter button while a filter is on.
  static const Key filterDotKey = Key('diaryTitleRow.filterDot');

  /// "Clear filter" under the title.
  static const Key clearKey = Key('diaryTitleRow.clear');

  /// The chip of the search text in the summary.
  static const Key queryChipKey = Key('diaryTitleRow.queryChip');

  /// The "Without tags" chip in the summary.
  static const Key untaggedChipKey = Key('diaryTitleRow.untaggedChip');

  static const double _dotSize = 7;

  /// Opens the filter sheet on the Diary's filter; the Diary follows every
  /// change, and the result when the sheet closes with Done.
  static Future<void> openFilter(BuildContext context) async {
    final DiaryCubit cubit = context.read<DiaryCubit>();
    final List<TagCount> tags =
        cubit.state.index?.tagCounts ?? const <TagCount>[];
    final ClipFilter? chosen = await DiaryFilterSheet.show(
      context,
      cubit: cubit,
      tags: tags,
      initial: cubit.state.filter,
      onChanged: cubit.setFilter,
    );
    if (chosen != null && !cubit.isClosed) cubit.setFilter(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final (DiaryView view, bool filtered) = context.select(
      (DiaryCubit cubit) => (cubit.state.view, cubit.state.isFiltered),
    );
    final OsdColors colors = context.colors;
    final String title = switch (view) {
      DiaryView.calendar => Strings.calendar,
      DiaryView.memories => Strings.memories,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 16, 2),
          child: Row(
            spacing: 12,
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: OsdTextSwap(
                      title,
                      textKey: titleKey,
                      textScaler: OsdTextScale.scalerFor(
                        context,
                        OsdTextScaleRole.display,
                      ),
                      style: context.typography.title30.copyWith(
                        color: colors.tx,
                      ),
                    ),
                  ),
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  OsdIconButton(
                    key: filterKey,
                    icon: OsdIcons.filterList,
                    tooltip: Strings.diaryFilter,
                    color: filtered ? colors.co : null,
                    onPressed: () => unawaited(openFilter(context)),
                  ),
                  if (filtered)
                    PositionedDirectional(
                      top: 9,
                      end: 9,
                      child: IgnorePointer(
                        child: SizedBox.square(
                          key: filterDotKey,
                          dimension: _dotSize,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.co,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              ViewToggle(
                options: <ViewToggleOption>[
                  ViewToggleOption(
                    icon: OsdIcons.calendarViewMonth,
                    tooltip: Strings.diaryViewCalendar,
                  ),
                  ViewToggleOption(
                    icon: OsdIcons.viewAgenda,
                    tooltip: Strings.diaryViewMemories,
                  ),
                ],
                index: view.index,
                onChanged: (int index) => context.read<DiaryCubit>().showView(
                  DiaryView.values[index],
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: OsdMotion.d(context, OsdMotion.standard),
          curve: OsdMotion.curve(context, OsdMotion.standardCurve),
          alignment: AlignmentDirectional.topStart,
          child: filtered ? const _FilterSummary() : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// What the filter keeps, under the title: its chips, the match count and
/// Clear.
class _FilterSummary extends StatelessWidget {
  const _FilterSummary();

  @override
  Widget build(BuildContext context) {
    final (ClipFilter filter, int matches) = context.select(
      (DiaryCubit cubit) => (cubit.state.filter, cubit.state.matchCount),
    );
    final DiaryCubit cubit = context.read<DiaryCubit>();
    final TagColors tagColors = context.read<TagColors>();
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        OsdSpace.pageGutter,
        OsdSpace.s4,
        OsdSpace.pageGutter,
        OsdSpace.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: OsdSpace.s6,
        children: <Widget>[
          Wrap(
            spacing: OsdSpace.s6,
            runSpacing: OsdSpace.s6,
            children: <Widget>[
              for (final String tag in filter.tags.anyOf)
                TagChip(
                  label: tag,
                  color: tagColors.colorOf(tag),
                  compact: true,
                  onRemove: () => cubit.setFilter(
                    filter.withTags(filter.tags.toggleAny(tag)),
                  ),
                ),
              if (filter.tags.untaggedOnly)
                TagChip(
                  key: DiaryTitleRow.untaggedChipKey,
                  label: Strings.diaryFilterUntagged,
                  color: colors.mu,
                  compact: true,
                  onRemove: () => cubit.setFilter(
                    filter.withTags(
                      filter.tags.withUntaggedOnly(untaggedOnly: false),
                    ),
                  ),
                ),
              if (filter.hasQuery)
                TagChip(
                  key: DiaryTitleRow.queryChipKey,
                  label: '“${filter.query.trim()}”',
                  color: colors.co,
                  compact: true,
                  onRemove: () => cubit.setFilter(filter.withQuery('')),
                ),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  Strings.diaryFilterMatches(
                    matches,
                    format: DiaryFormats.of(context).numbers,
                  ),
                  style: typography.caption13.copyWith(color: colors.sub),
                ),
              ),
              OsdTextButton(
                key: DiaryTitleRow.clearKey,
                label: Strings.diaryFilterClear,
                tone: OsdTextButtonTone.secondary,
                hug: true,
                onPressed: cubit.clearFilter,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
