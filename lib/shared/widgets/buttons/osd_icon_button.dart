import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button_frame.dart';
import 'package:one_second_diary/theme/osd_colors.dart';

/// The plain unfilled icon button of app bars, the selection bar and the
/// viewer bar.
///
/// Disabled turns the glyph DIS, or fades the button when [fadeWhenDisabled].
class OsdIconButton extends StatelessWidget {
  const OsdIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
    this.fill = 0,
    this.fadeWhenDisabled = false,
  });

  final IconData icon;

  /// The tooltip and semantics label.
  final String tooltip;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  /// The glyph colour; TX by default.
  final Color? color;

  /// The glyph's FILL value.
  final double fill;

  final bool fadeWhenDisabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OsdIconButtonFrame(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      visualSize: 44,
      glyphSize: 22,
      glyphFill: fill,
      glyphColor: color ?? colors.tx,
      disabledColor: fadeWhenDisabled ? null : colors.dis,
    );
  }
}
