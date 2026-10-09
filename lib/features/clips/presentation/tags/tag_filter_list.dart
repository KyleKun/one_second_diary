import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';
import 'package:one_second_diary/shared/widgets/controls/tag_chip.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The body of a tag filter: a search field that narrows the list, then
/// the tags as selectable chips with their counts, an optional "Without
/// tags" chip first. Pure: the caller holds the selection.
///
/// Shared by the Diary's filter sheet and the movie flow's "Only videos
/// tagged…" / "Leave out videos tagged…" sheets.
class TagFilterList extends StatefulWidget {
  const TagFilterList({
    super.key,
    required this.tags,
    required this.selected,
    required this.onToggle,
    required this.colorOf,
    this.untagged,
    this.onUntaggedChanged,
    this.query = '',
    this.onQueryChanged,
    this.searchHint,
    this.autofocus = false,
  });

  static const Key fieldKey = Key('tagFilterList.field');
  static const Key untaggedKey = Key('tagFilterList.untagged');
  static Key chipKey(String tag) =>
      ValueKey<String>('tagFilterList.chip.${TagName.fold(tag)}');

  /// The vocabulary, in the order to show (`ClipIndex.tagCounts`).
  final List<TagCount> tags;

  /// The selected tag names (compared by `TagName.fold`).
  final Set<String> selected;

  final void Function(String tag) onToggle;

  /// The colour of each tag (`TagColors.colorOf`).
  final Color Function(String tag) colorOf;

  /// Shows the "Without tags" chip when not null, with this value.
  final bool? untagged;
  final ValueChanged<bool>? onUntaggedChanged;

  /// The search text; the list shows the tags it matches. The caller may
  /// keep it (the Diary searches subtitles and places with it too).
  final String query;
  final ValueChanged<String>? onQueryChanged;
  final String? searchHint;
  final bool autofocus;

  @override
  State<TagFilterList> createState() => _TagFilterListState();
}

class _TagFilterListState extends State<TagFilterList> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.query,
  );

  @override
  void didUpdateWidget(TagFilterList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query && widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isSelected(String tag) {
    final String key = TagName.fold(tag);
    return widget.selected.any((String other) => TagName.fold(other) == key);
  }

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final String needle = TagName.fold(widget.query);
    final List<TagCount> shown = <TagCount>[
      for (final TagCount tag in widget.tags)
        if (needle.isEmpty || TagName.fold(tag.name).contains(needle)) tag,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.s12,
      children: <Widget>[
        if (widget.onQueryChanged != null)
          OsdTextField(
            key: TagFilterList.fieldKey,
            controller: _controller,
            hint: widget.searchHint,
            leadingIcon: OsdIcons.search,
            autofocus: widget.autofocus,
            textInputAction: TextInputAction.search,
            onChanged: widget.onQueryChanged,
          ),
        if (widget.tags.isNotEmpty && widget.untagged != null)
          Text(
            Strings.diaryFilterTagsHint,
            style: typography.caption13.copyWith(color: colors.mu),
          ),
        if (widget.tags.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: OsdSpace.s8),
            child: Text(
              Strings.diaryFilterNoTags,
              style: typography.body14.copyWith(color: colors.sub),
            ),
          )
        else
          Wrap(
            spacing: OsdSpace.s8,
            runSpacing: OsdSpace.s8,
            children: <Widget>[
              if (widget.untagged case final bool untagged when needle.isEmpty)
                TagChip(
                  key: TagFilterList.untaggedKey,
                  label: Strings.diaryFilterUntagged,
                  color: colors.mu,
                  selected: untagged,
                  onTap: () => widget.onUntaggedChanged?.call(!untagged),
                ),
              for (final TagCount tag in shown)
                TagChip(
                  key: TagFilterList.chipKey(tag.name),
                  label: '${tag.name} · ${tag.count}',
                  color: widget.colorOf(tag.name),
                  selected: _isSelected(tag.name),
                  onTap: () => widget.onToggle(tag.name),
                  semanticsLabel:
                      '${tag.name}, ${Strings.tagVideoCount(tag.count)}',
                ),
            ],
          ),
      ],
    );
  }
}
