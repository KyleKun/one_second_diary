import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_frame.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A small C2 pill that hugs its label.
class OsdPillButton extends StatelessWidget {
  const OsdPillButton({super.key, required this.label, this.onPressed});

  static const Key surfaceKey = OsdButtonFrame.surfaceKey;

  final String label;

  /// Called on tap; null disables the pill.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OsdButtonFrame(
      label: label,
      onPressed: onPressed,
      labelStyle: context.typography.sectionLabel,
      foreground: colors.tx,
      fill: colors.c2,
      minHeight: 0,
      radius: OsdRadius.r10,
      hug: true,
      horizontalPadding: 12,
      verticalPadding: 7,
      pressScale: .95,
    );
  }
}
