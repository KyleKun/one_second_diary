import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tag_filter_list.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// A sheet to pick tags: the vocabulary as chips with counts, a search
/// field, Done. Pops with the picked names, or null when dismissed.
class TagFilterSheet extends StatefulWidget {
  const TagFilterSheet({
    super.key,
    required this.tags,
    required this.initial,
    required this.searchHint,
    required this.doneLabel,
  });

  static const Key doneKey = Key('tagFilterSheet.done');

  final List<TagCount> tags;
  final Set<String> initial;
  final String searchHint;
  final String doneLabel;

  /// Shows the sheet; resolves with the picked tags, or null if dismissed.
  static Future<Set<String>?> show(
    BuildContext context, {
    required String title,
    required List<TagCount> tags,
    required Set<String> initial,
    required String searchHint,
  }) => showOsdSheet<Set<String>>(
    context,
    title: title,
    height: OsdSheetHeight.tall,
    child: TagFilterSheet(
      tags: tags,
      initial: initial,
      searchHint: searchHint,
      doneLabel: Strings.done,
    ),
  );

  @override
  State<TagFilterSheet> createState() => _TagFilterSheetState();
}

class _TagFilterSheetState extends State<TagFilterSheet> {
  late Set<String> _selected = Set<String>.of(widget.initial);
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final TagColors colors = context.read<TagColors>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.s16,
      children: <Widget>[
        TagFilterList(
          tags: widget.tags,
          selected: _selected,
          colorOf: colors.colorOf,
          query: _query,
          onQueryChanged: (String query) => setState(() => _query = query),
          searchHint: widget.searchHint,
          onToggle: (String tag) => setState(() {
            final Set<String> next = Set<String>.of(_selected);
            if (!next.remove(tag)) next.add(tag);
            _selected = next;
          }),
        ),
        PrimaryButton(
          key: TagFilterSheet.doneKey,
          label: widget.doneLabel,
          onPressed: () => Navigator.of(context).pop(_selected),
        ),
      ],
    );
  }
}
