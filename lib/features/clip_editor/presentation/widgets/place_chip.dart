import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A place to pick in the place sheet: a purple-tinted stadium with a
/// `place` pin and the name. A tap gives the clip that place.
class PlaceChip extends StatelessWidget {
  const PlaceChip({super.key, required this.label, required this.onTap});

  final String label;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    return OsdPressable(
      onTap: onTap,
      haptic: OsdHaptic.selection,
      pressScale: OsdPressScale.actionTile.scale,
      overlay: OsdPressOverlay.none,
      borderRadius: BorderRadius.circular(OsdRadius.full),
      semanticsLabel: label,
      excludeChildSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.purple.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(OsdRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: <Widget>[
            OsdIcon(OsdIcons.place, size: 14, color: colors.purple),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.chipLabel.copyWith(color: colors.tx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
