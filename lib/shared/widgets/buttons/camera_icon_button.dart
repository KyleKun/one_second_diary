import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button_frame.dart';
import 'package:one_second_diary/theme/osd_camera.dart';
import 'package:one_second_diary/theme/osd_colors.dart';

/// Camera icon buttons, for the forced-dark camera screens.
class CameraIconButton extends StatelessWidget {
  /// The glass button over the preview.
  const CameraIconButton.glass({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  }) : solid = false,
       glyphSize = 22;

  /// The solid button in the camera panel.
  const CameraIconButton.solid({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.glyphSize = 24,
  }) : solid = true;

  final IconData icon;

  /// The tooltip and semantics label.
  final String tooltip;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  final bool solid;

  final double glyphSize;

  @override
  Widget build(BuildContext context) => OsdIconButtonFrame(
    icon: icon,
    tooltip: tooltip,
    onPressed: onPressed,
    visualSize: solid ? 52 : 44,
    hitSize: solid ? 52 : 48,
    glyphSize: glyphSize,
    glyphColor: context.colors.tx,
    fill: solid ? OsdCamera.surface : OsdCamera.glass,
  );
}
