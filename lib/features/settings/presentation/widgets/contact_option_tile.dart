import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_spinner.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// One way to contact the developer in the Contact dialog: a [tint] tile
/// with the [icon] in [accent], the title over the subtitle, and a chevron,
/// which becomes a spinner while [busy]. It reads as one button:
/// "{title}. {subtitle}".
class ContactOptionTile extends StatelessWidget {
  const ContactOptionTile({
    super.key,
    required this.icon,
    required this.accent,
    required this.tint,
    required this.title,
    required this.subtitle,
    this.busy = false,
    this.onTap,
  });

  /// The spinner shown while [busy].
  static const Key spinnerKey = Key('contactOptionTile.spinner');

  final IconData icon;
  final Color accent;
  final Color tint;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback? onTap;

  static const double _tile = 40;
  static const double _spinner = 18;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final BorderRadius radius = BorderRadius.circular(OsdRadius.r16);
    return OsdPressable(
      onTap: onTap,
      haptic: OsdHaptic.selection,
      pressScale: OsdMotion.pressScale(context, OsdPressScale.row),
      borderRadius: radius,
      semanticsLabel: '$title. $subtitle',
      excludeChildSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.c2, borderRadius: radius),
        child: Padding(
          padding: const EdgeInsets.all(OsdSpace.s14),
          child: Row(
            spacing: OsdSpace.s12,
            children: <Widget>[
              SizedBox.square(
                dimension: _tile,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(OsdRadius.r12),
                  ),
                  child: Center(child: OsdIcon(icon, fill: 1, color: accent)),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: OsdSpace.s2,
                  children: <Widget>[
                    // Never cut (the dialog scrolls): at a large text size
                    // the option says all of what it does.
                    Text(
                      title,
                      style: typography.rowTitleStrong.copyWith(
                        color: colors.tx,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: typography.captionContact.copyWith(
                        color: colors.mu,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                SizedBox.square(
                  dimension: OsdSizes.iconDefault,
                  child: Center(
                    child: OsdSpinner(
                      key: spinnerKey,
                      size: _spinner,
                      color: colors.mu,
                    ),
                  ),
                )
              else
                OsdIcon(OsdIcons.chevronRight, color: colors.fa),
            ],
          ),
        ),
      ),
    );
  }
}
