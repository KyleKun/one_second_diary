import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button_frame.dart';
import 'package:one_second_diary/theme/osd_colors.dart';

/// The unfilled chevron button of the year stepper.
class YearStepperButton extends StatelessWidget {
  const YearStepperButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;

  /// The tooltip and semantics label.
  final String tooltip;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OsdIconButtonFrame(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      visualSize: 40,
      glyphSize: 22,
      glyphColor: colors.tx,
      disabledColor: colors.dis,
    );
  }
}
