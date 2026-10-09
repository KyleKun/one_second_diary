import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The look of an [OsdActionRow].
enum OsdActionRowTone {
  /// A coral circle with a filled glyph.
  primary,

  /// An OFF circle with a D2 glyph.
  neutral,

  /// RED label and glyph.
  destructive,
}

/// A standalone C2 action tile of the source sheets: an icon circle, then a
/// label.
class OsdActionRow extends StatelessWidget {
  const OsdActionRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.tone = OsdActionRowTone.neutral,
  });

  static const Key surfaceKey = Key('osdActionRow.surface');

  static const Key circleKey = Key('osdActionRow.circle');

  final IconData icon;

  final String label;

  /// Called on tap; null disables the row.
  final VoidCallback? onTap;

  final OsdActionRowTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(OsdRadius.r18);
    final primary = tone == OsdActionRowTone.primary;
    final ink = tone == OsdActionRowTone.destructive ? colors.red : colors.tx;
    final Widget row = OsdPressable(
      opacity: OsdPressable.opacityFor(enabled: onTap != null),
      onTap: onTap,
      pressScale: OsdPressScale.button.scale,
      borderRadius: radius,
      child: DecoratedBox(
        key: surfaceKey,
        decoration: BoxDecoration(color: colors.c2, borderRadius: radius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              spacing: 12,
              children: <Widget>[
                SizedBox.square(
                  key: circleKey,
                  dimension: 40,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary ? colors.co : colors.off,
                    ),
                    child: Center(
                      child: OsdIcon(
                        icon,
                        fill: primary ? 1 : 0,
                        color: switch (tone) {
                          OsdActionRowTone.primary => colors.onCo,
                          OsdActionRowTone.neutral => colors.d2,
                          OsdActionRowTone.destructive => colors.red,
                        },
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    label,
                    style: context.typography.buttonNeutral.copyWith(
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return row;
  }
}
