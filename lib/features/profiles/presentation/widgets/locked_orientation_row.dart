import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/profiles/presentation/profile_labels.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The locked orientation of "Edit profile", with a lock. It is no button
/// (one text node for screen readers), but a tap wiggles the lock with a
/// light haptic (haptic only under reduced motion).
class LockedOrientationRow extends StatefulWidget {
  const LockedOrientationRow({super.key, required this.orientation});

  /// The `lock` glyph that wiggles.
  static const Key lockKey = Key('lockedOrientationRow.lock');

  final VideoOrientation orientation;

  @override
  State<LockedOrientationRow> createState() => _LockedOrientationRowState();
}

class _LockedOrientationRowState extends State<LockedOrientationRow>
    with SingleTickerProviderStateMixin {
  static const Duration _wiggleDuration = Duration(milliseconds: 360);

  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: _wiggleDuration,
  );

  /// The lock's rotation, in turns.
  late final Animation<double> _turns = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      for (final (double from, double to) in <(double, double)>[
        (0, 10),
        (10, -8),
        (-8, 5),
        (5, 0),
      ])
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: from / 360, end: to / 360),
          weight: 1,
        ),
    ],
  ).chain(CurveTween(curve: Curves.easeOut)).animate(_wiggle);

  void _answer() {
    unawaited(OsdHaptic.light.play());
    if (!OsdMotion.reduced(context)) unawaited(_wiggle.forward(from: 0));
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final String name = ProfileLabels.orientation(widget.orientation);
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: _answer,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.c2,
            borderRadius: BorderRadius.circular(OsdRadius.r16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              spacing: 12,
              children: <Widget>[
                OsdIcon(
                  widget.orientation == VideoOrientation.landscape
                      ? OsdIcons.stayCurrentLandscape
                      : OsdIcons.stayCurrentPortrait,
                  color: colors.mu,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 2,
                    children: <Widget>[
                      Text(
                        name,
                        style: typography.rowTitleStrong.copyWith(
                          color: colors.tx,
                        ),
                      ),
                      Text(
                        Strings.profileOrientationLocked,
                        style: typography.rowSubtitle.copyWith(
                          color: colors.mu,
                        ),
                      ),
                    ],
                  ),
                ),
                RotationTransition(
                  key: LockedOrientationRow.lockKey,
                  turns: _turns,
                  child: OsdIcon(OsdIcons.lock, color: colors.fa),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
