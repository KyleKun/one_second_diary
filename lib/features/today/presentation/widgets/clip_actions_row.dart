import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// The actions of a day with clips: Edit and Add another, small and side
/// by side in the middle.
class ClipActionsRow extends StatelessWidget {
  const ClipActionsRow({
    super.key,
    required this.onEdit,
    required this.onAddAnother,
  });

  static const Key editKey = Key('clipActionsRow.edit');

  static const Key addAnotherKey = Key('clipActionsRow.addAnother');

  /// Opens the Edit sheet for the clip in view.
  final VoidCallback onEdit;

  /// Adds another clip to the day.
  final VoidCallback onAddAnother;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: OsdSpace.s10,
    children: <Widget>[
      NeutralButton(
        key: editKey,
        icon: OsdIcons.edit,
        label: Strings.edit,
        size: OsdButtonSize.compact,
        hug: true,
        onPressed: onEdit,
      ),
      NeutralButton(
        key: addAnotherKey,
        icon: OsdIcons.add,
        label: Strings.todayAddAnother,
        size: OsdButtonSize.compact,
        hug: true,
        onPressed: onAddAnother,
      ),
    ],
  );
}
