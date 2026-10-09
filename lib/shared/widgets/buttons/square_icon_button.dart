import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button_frame.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_tints.dart';

/// A rounded-square icon button, red-tinted when [destructive].
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.destructive = false,
    this.selected = false,
  });

  final IconData icon;

  /// The tooltip and semantics label.
  final String tooltip;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  final bool destructive;

  /// Whether the button is a switch that is on: its glyph is filled.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OsdIconButtonFrame(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      visualSize: 46,
      radius: OsdRadius.r14,
      glyphSize: 20,
      glyphColor: destructive ? colors.red : colors.tx,
      glyphFill: selected ? 1 : 0,
      disabledColor: colors.dis,
      fill: destructive ? OsdTints.redTint12 : colors.btn,
    );
  }
}
