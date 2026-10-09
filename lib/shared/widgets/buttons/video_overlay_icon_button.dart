import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button_frame.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_overflow_hit_area.dart';
import 'package:one_second_diary/theme/osd_media.dart';

/// A scrim circle over video with a white glyph. It lays out at the circle,
/// so `Positioned(top: 10, start: 10)` draws it at 10 / 10, while its hit area
/// reaches past it (`OsdOverflowHitArea`). Theme-invariant.
class VideoOverlayIconButton extends StatelessWidget {
  const VideoOverlayIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.fill = 0,
  });

  final IconData icon;

  /// The tooltip and semantics label.
  final String tooltip;

  final VoidCallback? onPressed;

  /// The glyph's FILL value.
  final double fill;

  @override
  Widget build(BuildContext context) => OsdOverflowHitArea(
    child: OsdIconButtonFrame(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      visualSize: 36,
      glyphSize: 20,
      glyphFill: fill,
      glyphColor: OsdMedia.onMedia,
      fill: OsdMedia.scrim50,
    ),
  );
}
