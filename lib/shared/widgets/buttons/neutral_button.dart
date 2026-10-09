import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_frame.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_surface.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The secondary button.
///
/// The fill comes from the surface it sits on: BTN on BG, C2 on cards, sheets
/// and dialogs. Disabled keeps the fill and turns the content DIS.
class NeutralButton extends StatelessWidget {
  const NeutralButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.size = OsdButtonSize.standard,
    this.surface,
    this.hug = false,
    this.loading = false,
    this.autofocus = false,
  });

  static const Key surfaceKey = OsdButtonFrame.surfaceKey;

  final String label;

  final IconData? icon;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  final OsdButtonSize size;

  /// The surface underneath, when it differs from the ambient `OsdSurface`.
  final OsdSurfaceTone? surface;

  final bool hug;

  final bool loading;

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return OsdButtonFrame(
      label: label,
      icon: icon,
      onPressed: onPressed,
      labelStyle: size == OsdButtonSize.compact
          ? typography.rowTitleStrong
          : typography.buttonNeutral,
      foreground: onPressed == null && !loading ? colors.dis : colors.tx,
      fill: (surface ?? OsdSurface.of(context)).neutralFill(colors),
      minHeight: size.height,
      radius: size.radius,
      hug: hug,
      loading: loading,
      spinnerSize: 18,
      fadeWhenDisabled: false,
      autofocus: autofocus,
    );
  }
}
