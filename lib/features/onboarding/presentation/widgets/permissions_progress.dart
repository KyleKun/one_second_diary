import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Under the permission rows: a thin bar of what is allowed, and "2 of 5
/// allowed" (a live region), which becomes "You're all set" with the bar in
/// green once every row is allowed. The bar follows a change smoothly;
/// under reduced motion it jumps.
class PermissionsProgress extends StatelessWidget {
  const PermissionsProgress({
    super.key,
    required this.granted,
    required this.total,
  });

  static const Key trackKey = Key('permissionsProgress.track');

  static const Key fillKey = Key('permissionsProgress.fill');

  static const double _height = 6;

  /// How many rows are allowed.
  final int granted;

  /// How many rows show.
  final int total;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final bool allDone = total > 0 && granted >= total;
    final double share = total == 0 ? 0 : (granted / total).clamp(0, 1);
    final BorderRadius radius = BorderRadius.circular(_height / 2);
    final Duration duration = OsdMotion.d(context, OsdMotion.emphasized);
    final Curve curve = OsdMotion.curve(context, OsdMotion.standardCurve);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: OsdSpace.s10,
      children: <Widget>[
        ExcludeSemantics(
          child: SizedBox(
            height: _height,
            child: DecoratedBox(
              key: trackKey,
              decoration: BoxDecoration(
                color: colors.off,
                borderRadius: radius,
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: share),
                duration: duration,
                curve: curve,
                builder: (BuildContext context, double value, _) => Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: value,
                    heightFactor: 1,
                    child: AnimatedContainer(
                      key: fillKey,
                      duration: duration,
                      curve: curve,
                      decoration: BoxDecoration(
                        color: allDone ? colors.green : colors.co,
                        borderRadius: radius,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Semantics(
          liveRegion: true,
          child: Row(
            spacing: OsdSpace.chipIconGap,
            children: <Widget>[
              if (allDone)
                OsdIcon(
                  OsdIcons.checkCircle,
                  size: 18,
                  fill: 1,
                  color: colors.greenInk,
                ),
              Expanded(
                child: Text(
                  allDone
                      ? Strings.onboardingPermissionsAllDone
                      : Strings.onboardingPermissionsProgress(
                          granted: granted,
                          total: total,
                        ),
                  style: context.typography.label13.copyWith(
                    color: allDone ? colors.greenInk : colors.mu,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
