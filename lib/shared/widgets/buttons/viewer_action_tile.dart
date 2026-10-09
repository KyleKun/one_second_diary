import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_tints.dart';
import 'package:one_second_diary/theme/osd_typography.dart';
import 'package:one_second_diary/theme/osd_viewer.dart';

/// An action tile under the viewer (forced dark): a glyph over a label.
/// The [destructive] tile is red-tinted with a RED glyph and label; a
/// [selected] tile (a switch that is on) has its glyph filled.
///
/// [compact] is the tile of a phone turned sideways, where the tiles lie
/// over the video: the glyph alone in a small square, the label its
/// tooltip and what a screen reader says.
class ViewerActionTile extends StatelessWidget {
  const ViewerActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.destructive = false,
    this.selected = false,
    this.compact = false,
  });

  static const Key surfaceKey = Key('viewerActionTile.surface');

  /// A compact tile's side.
  static const double compactSize = 44;

  final IconData icon;

  final String label;

  /// Called on tap; null disables the tile.
  final VoidCallback? onPressed;

  final bool destructive;

  /// Whether the tile is a switch that is on.
  final bool selected;

  /// Whether it is the glyph alone.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = destructive ? colors.red : colors.tx;
    final radius = BorderRadius.circular(
      compact ? OsdRadius.r12 : OsdRadius.r16,
    );
    final Widget tile = OsdPressable(
      opacity: OsdPressable.opacityFor(enabled: onPressed != null),
      onTap: onPressed,
      tooltip: compact ? label : null,
      pressScale: OsdPressScale.actionTile.scale,
      overlay: OsdPressOverlay.none,
      borderRadius: radius,
      child: Builder(
        builder: (context) {
          final pressed = OsdPressable.isPressed(context);
          return AnimatedContainer(
            key: surfaceKey,
            duration: OsdMotion.d(
              context,
              pressed ? OsdMotion.overlayIn : OsdMotion.overlayOut,
            ),
            constraints: compact
                ? const BoxConstraints.tightFor(
                    width: compactSize,
                    height: compactSize,
                  )
                : const BoxConstraints(minHeight: 64),
            padding: compact
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: radius,
              color: destructive
                  ? (pressed
                        ? Color.alphaBlend(
                            OsdTints.redTint12,
                            OsdViewer.tilePressed,
                          )
                        : OsdTints.redTint12)
                  : (pressed ? OsdViewer.tilePressed : OsdViewer.tile),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: <Widget>[
                OsdIcon(icon, size: 22, fill: selected ? 1 : 0, color: ink),
                if (!compact)
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    textScaler: OsdTextScale.scalerFor(
                      context,
                      OsdTextScaleRole.mediaChrome,
                    ),
                    style: context.typography.label13.copyWith(color: ink),
                  ),
              ],
            ),
          );
        },
      ),
    );
    return tile;
  }
}
