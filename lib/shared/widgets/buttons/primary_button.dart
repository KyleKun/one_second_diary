import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_frame.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The coral action button. Coral is for actions only, never for destructive
/// actions or selection.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.size = OsdButtonSize.standard,
    this.emphasis = false,
    this.hug = false,
    this.loading = false,
    this.loadingLabel,
    this.haptic,
    this.autofocus = false,
  });

  static const Key surfaceKey = OsdButtonFrame.surfaceKey;

  final String label;

  final IconData? icon;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  final OsdButtonSize size;

  /// Uses the larger label style at the standard size.
  final bool emphasis;

  final bool hug;

  final bool loading;

  final String? loadingLabel;

  /// Played on tap.
  final OsdHaptic? haptic;

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return OsdButtonFrame(
      label: label,
      icon: icon,
      onPressed: onPressed,
      labelStyle: switch (size) {
        OsdButtonSize.compact => typography.titleSmall,
        OsdButtonSize.hero => typography.buttonLarge,
        _ when emphasis => typography.buttonLarge,
        _ => typography.button,
      },
      foreground: colors.onCo,
      fill: colors.coFill,
      minHeight: size.height,
      radius: size.radius,
      hug: hug,
      loading: loading,
      loadingLabel: loadingLabel,
      overlay: OsdPressOverlay.darken,
      haptic: haptic,
      autofocus: autofocus,
    );
  }
}
