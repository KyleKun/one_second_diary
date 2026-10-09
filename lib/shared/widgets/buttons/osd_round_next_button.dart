import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button_frame.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// Onboarding "Next": a coral circle with a forward arrow.
class OsdRoundNextButton extends StatelessWidget {
  const OsdRoundNextButton({super.key, required this.tooltip, this.onPressed});

  /// The tooltip and semantics label.
  final String tooltip;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OsdIconButtonFrame(
      icon: OsdIcons.arrowForward,
      tooltip: tooltip,
      onPressed: onPressed,
      visualSize: 58,
      glyphSize: 22,
      glyphColor: colors.onCo,
      fill: colors.coFill,
      overlay: OsdPressOverlay.darken,
      haptic: OsdHaptic.light,
    );
  }
}
