import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/presentation/privacy/private_clips_help_sheet.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The small "?" beside a private-video control: opens
/// [PrivateClipsHelpSheet] over whatever shows it (a sheet stacks it).
class PrivateHelpButton extends StatelessWidget {
  const PrivateHelpButton({super.key, this.color});

  /// The glyph colour; the icon button's own by default.
  final Color? color;

  @override
  Widget build(BuildContext context) => OsdIconButton(
    icon: OsdIcons.help,
    tooltip: Strings.privateHelpTitle,
    color: color,
    onPressed: () => unawaited(PrivateClipsHelpSheet.show(context)),
  );
}
