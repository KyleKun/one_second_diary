import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/presentation/privacy/private_help_button.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_action_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The private row of a clip's action sheet (Memories, Today's Edit):
/// "Make private", or "Make public" for a clip that is, with the "?" that
/// explains it beside the tile.
class PrivacyActionRow extends StatelessWidget {
  const PrivacyActionRow({
    super.key,
    required this.isPrivate,
    required this.onTap,
  });

  /// The tile itself.
  static const Key tileKey = Key('privacyActionRow.tile');

  static const Key helpKey = Key('privacyActionRow.help');

  /// Whether the clip is private now.
  final bool isPrivate;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 4,
    children: <Widget>[
      Expanded(
        child: OsdActionRow(
          key: tileKey,
          icon: OsdIcons.lock,
          label: isPrivate ? Strings.makePublic : Strings.makePrivate,
          onTap: onTap,
        ),
      ),
      const PrivateHelpButton(key: helpKey),
    ],
  );
}
