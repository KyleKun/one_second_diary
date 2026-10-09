import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_frame.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The destructive confirm button. Never use coral for a destructive action.
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.size = OsdButtonSize.dense,
    this.loading = false,
    this.hug = false,
  });

  static const Key surfaceKey = OsdButtonFrame.surfaceKey;

  final String label;

  final IconData? icon;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  final OsdButtonSize size;

  final bool loading;

  final bool hug;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OsdButtonFrame(
      label: label,
      icon: icon,
      onPressed: onPressed,
      labelStyle: context.typography.buttonNeutral,
      foreground: colors.bg,
      fill: colors.red,
      minHeight: size.height,
      radius: size.radius,
      hug: hug,
      loading: loading,
      spinnerSize: 18,
      overlay: OsdPressOverlay.darken,
      haptic: OsdHaptic.medium,
    );
  }
}
