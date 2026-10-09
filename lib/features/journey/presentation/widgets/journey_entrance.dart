import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/fade_rise.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// A Journey tile's first appearance: it fades in and rises, [index]
/// stagger steps after the first, driven by the page's [animation] (0 → 1
/// once per session). Only transform and opacity move; the layout never
/// does.
class JourneyEntrance extends StatelessWidget {
  const JourneyEntrance({
    super.key,
    required this.animation,
    required this.index,
    required this.child,
  });

  /// The whole page's entrance: the last of [itemCount] items ends at 1.
  static Duration get duration =>
      OsdMotion.entrance + OsdMotion.entranceStagger * (itemCount - 1);

  /// How many items the page staggers.
  static const int itemCount = 6;

  final Animation<double> animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final int total = duration.inMicroseconds;
    final Duration start = OsdMotion.entranceStagger * index;
    // Built on every rebuild: a CurveTween keeps no listener of its own on
    // [animation], where a CurvedAnimation made here would leak one.
    final Animation<double> t = animation.drive(
      CurveTween(
        curve: Interval(
          start.inMicroseconds / total,
          (start + OsdMotion.entrance).inMicroseconds / total,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    return FadeRise(animation: t, rise: OsdMotion.entranceRise, child: child);
  }
}
