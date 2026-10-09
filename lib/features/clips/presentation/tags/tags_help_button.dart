import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tags_help_sheet.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The small "?" beside a tags control: opens [TagsHelpSheet] over whatever
/// shows it (a sheet stacks it).
class TagsHelpButton extends StatelessWidget {
  const TagsHelpButton({super.key, this.color});

  /// The glyph colour; the icon button's own by default.
  final Color? color;

  @override
  Widget build(BuildContext context) => OsdIconButton(
    icon: OsdIcons.help,
    tooltip: Strings.tagsHelpTitle,
    color: color,
    onPressed: () => unawaited(TagsHelpSheet.show(context)),
  );
}
