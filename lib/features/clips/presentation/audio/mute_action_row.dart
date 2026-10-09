import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_action_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The mute row of a clip's action sheet: "Remove audio", or "Audio
/// removed" and nothing to tap for a clip that is (muting is for good).
class MuteActionRow extends StatelessWidget {
  const MuteActionRow({super.key, required this.isMuted, required this.onTap});

  /// The tile itself.
  static const Key tileKey = Key('muteActionRow.tile');

  /// Whether the clip is muted already.
  final bool isMuted;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OsdActionRow(
    key: tileKey,
    icon: OsdIcons.volumeOff,
    label: isMuted ? Strings.clipMuted : Strings.clipMute,
    onTap: isMuted ? null : onTap,
  );
}
