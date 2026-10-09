import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_frame.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A transparent stadium with a TX border. It hugs its content; under large
/// text the label may wrap to 2 lines.
class OutlinedPillButton extends StatelessWidget {
  const OutlinedPillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  static const Key surfaceKey = OsdButtonFrame.surfaceKey;

  final String label;

  final IconData? icon;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OsdButtonFrame(
      label: label,
      icon: icon,
      onPressed: onPressed,
      labelStyle: context.typography.titleSmall,
      foreground: colors.tx,
      border: BorderSide(color: colors.tx, width: 1.5),
      minHeight: 46,
      radius: OsdRadius.full,
      hug: true,
      horizontalPadding: 18,
      verticalPadding: 6,
      maxLines: 2,
    );
  }
}
