import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The small bar under the "This month" tile. On first show it grows
/// 0 → [value] after a short delay, once; under reduced motion (or with
/// [animate] off) it shows the value at once. Decorative: the tile's value
/// carries the number.
class MiniProgressBar extends StatefulWidget {
  const MiniProgressBar({super.key, required this.value, this.animate = true});

  static const Key trackKey = Key('miniProgressBar.track');

  static const Key fillKey = Key('miniProgressBar.fill');

  static const Duration _delay = Duration(milliseconds: 150);

  /// The share recorded, 0 to 1.
  final double value;

  /// Whether it grows in when first shown.
  final bool animate;

  @override
  State<MiniProgressBar> createState() => _MiniProgressBarState();
}

class _MiniProgressBarState extends State<MiniProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: MiniProgressBar._delay + OsdMotion.countUp,
    value: 1,
  );

  // A CurveTween needs no disposal (a CurvedAnimation's listener on [_grow]
  // would outlive this state until the controller goes).
  late final Animation<double> _progress = _grow.drive(
    CurveTween(
      curve: Interval(
        MiniProgressBar._delay.inMicroseconds /
            (MiniProgressBar._delay + OsdMotion.countUp).inMicroseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
    ),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.animate && !OsdMotion.reduced(context)) {
      unawaited(_grow.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(3);
    return ExcludeSemantics(
      child: SizedBox(
        height: 6,
        child: DecoratedBox(
          key: MiniProgressBar.trackKey,
          decoration: BoxDecoration(color: colors.off, borderRadius: radius),
          child: AnimatedBuilder(
            animation: _progress,
            builder: (context, child) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor:
                    widget.value.clamp(0, 1).toDouble() * _progress.value,
                heightFactor: 1,
                child: child,
              ),
            ),
            child: DecoratedBox(
              key: MiniProgressBar.fillKey,
              decoration: BoxDecoration(
                color: colors.green,
                borderRadius: radius,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
