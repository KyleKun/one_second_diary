import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tags_help_button.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_action_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The tags row of a clip's action sheet (Memories, Today's Edit): "Edit
/// tags", with the "?" that explains tags beside the tile.
class TagsActionRow extends StatelessWidget {
  const TagsActionRow({super.key, required this.onTap});

  /// The tile itself.
  static const Key tileKey = Key('tagsActionRow.tile');

  static const Key helpKey = Key('tagsActionRow.help');

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 4,
    children: <Widget>[
      Expanded(
        child: OsdActionRow(
          key: tileKey,
          icon: OsdIcons.sell,
          label: Strings.editTags,
          onTap: onTap,
        ),
      ),
      const TagsHelpButton(key: helpKey),
    ],
  );
}
