import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button_frame.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_overflow_hit_area.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_viewer.dart';

/// The viewer's previous/next day button (forced dark). It lays out at the
/// circle while its hit area reaches past it (`OsdOverflowHitArea`).
///
/// At the first or last recorded day it fades out ([visible] false) and
/// leaves semantics and hit testing.
class ViewerNavButton extends StatelessWidget {
  const ViewerNavButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.visible = true,
  });

  final IconData icon;

  /// The tooltip and semantics label.
  final String tooltip;

  final VoidCallback? onPressed;

  final bool visible;

  @override
  Widget build(BuildContext context) => OsdOverflowHitArea(
    child: AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: OsdMotion.d(context, OsdMotion.fast),
      child: IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: OsdIconButtonFrame(
            icon: icon,
            tooltip: tooltip,
            onPressed: onPressed,
            visualSize: 40,
            glyphSize: 24,
            glyphColor: context.colors.tx,
            fill: OsdViewer.navButton,
          ),
        ),
      ),
    ),
  );
}
