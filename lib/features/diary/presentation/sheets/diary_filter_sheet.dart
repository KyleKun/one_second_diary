import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tag_filter_list.dart';
import 'package:one_second_diary/features/diary/domain/clip_filter.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// The Diary's filter sheet: a search field (tags, subtitles and places),
/// then the profile's tags with their counts as chips (any of them, or
/// "Without tags"), Clear and a Done button that counts the matches.
///
/// It starts from [initial], tells [onChanged] every change (the Diary
/// applies it live under the sheet, and the count follows) and pops with
/// the [ClipFilter] chosen, or null when dismissed (the live changes
/// stand). "Without tags" and chosen tags exclude each other: picking one
/// lets go of the other.
class DiaryFilterSheet extends StatefulWidget {
  const DiaryFilterSheet({
    super.key,
    required this.tags,
    required this.initial,
    this.onChanged,
  });

  static const Key doneKey = Key('diaryFilterSheet.done');
  static const Key clearKey = Key('diaryFilterSheet.clear');

  /// The profile's vocabulary (`ClipIndex.tagCounts`).
  final List<TagCount> tags;

  final ClipFilter initial;

  /// Hears every change while the sheet is open.
  final ValueChanged<ClipFilter>? onChanged;

  /// Shows the sheet over [context] for the Diary of [cubit] (its match
  /// count); resolves with the filter chosen, or null when dismissed.
  static Future<ClipFilter?> show(
    BuildContext context, {
    required DiaryCubit cubit,
    required List<TagCount> tags,
    required ClipFilter initial,
    ValueChanged<ClipFilter>? onChanged,
  }) => showOsdSheet<ClipFilter>(
    context,
    title: Strings.diaryFilterTitle,
    height: OsdSheetHeight.tall,
    child: BlocProvider<DiaryCubit>.value(
      value: cubit,
      child: DiaryFilterSheet(
        tags: tags,
        initial: initial,
        onChanged: onChanged,
      ),
    ),
  );

  @override
  State<DiaryFilterSheet> createState() => _DiaryFilterSheetState();
}

class _DiaryFilterSheetState extends State<DiaryFilterSheet> {
  late ClipFilter _filter = widget.initial;

  void _set(ClipFilter filter) {
    setState(() => _filter = filter);
    widget.onChanged?.call(filter);
  }

  void _toggle(String tag) => _set(
    _filter.withTags(
      _filter.tags.toggleAny(tag).withUntaggedOnly(untaggedOnly: false),
    ),
  );

  void _untagged(bool on) => _set(
    _filter.withTags(
      on
          ? TagFilter(untaggedOnly: true)
          : _filter.tags.withUntaggedOnly(untaggedOnly: false),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final TagColors colors = context.read<TagColors>();
    final int matches = context.select(
      (DiaryCubit cubit) => cubit.state.matchCount,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.s16,
      children: <Widget>[
        TagFilterList(
          tags: widget.tags,
          selected: _filter.tags.anyOf,
          colorOf: colors.colorOf,
          untagged: _filter.tags.untaggedOnly,
          onUntaggedChanged: _untagged,
          query: _filter.query,
          onQueryChanged: (String query) => _set(_filter.withQuery(query)),
          searchHint: Strings.diarySearchHint,
          onToggle: _toggle,
        ),
        if (_filter.isNotEmpty)
          OsdTextButton(
            key: DiaryFilterSheet.clearKey,
            label: Strings.diaryFilterClear,
            tone: OsdTextButtonTone.secondary,
            onPressed: () => _set(const ClipFilter.none()),
          ),
        PrimaryButton(
          key: DiaryFilterSheet.doneKey,
          label: _filter.isEmpty
              ? Strings.done
              : matches == 0
              ? Strings.diaryFilterNoMatches
              : Strings.diaryFilterShow(
                  matches,
                  format: DiaryFormats.of(context).numbers,
                ),
          onPressed: () => Navigator.of(context).pop(_filter),
        ),
      ],
    );
  }
}
