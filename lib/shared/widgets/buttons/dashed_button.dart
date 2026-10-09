import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_frame.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A full-width dashed button with no fill.
class DashedButton extends StatelessWidget {
  const DashedButton({
    super.key,
    required this.label,
    this.icon = OsdIcons.add,
    this.onPressed,
  });

  static const Key surfaceKey = OsdButtonFrame.surfaceKey;

  final String label;

  final IconData icon;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OsdButtonFrame(
      label: label,
      icon: icon,
      onPressed: onPressed,
      labelStyle: context.typography.rowTitleStrong,
      foreground: colors.d2,
      dashColor: colors.fa,
      minHeight: 50,
      radius: OsdRadius.r16,
    );
  }
}
