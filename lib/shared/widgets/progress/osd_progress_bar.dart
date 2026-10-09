import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The movie-making progress bar. While [finishing] (the last step), the
/// fill pulses; under reduced motion it holds still but the width still
/// progresses. The page announces progress, so the bar itself is decorative.
class OsdProgressBar extends StatefulWidget {
  const OsdProgressBar({
    super.key,
    required this.value,
    this.finishing = false,
  });

  static const Key trackKey = Key('osdProgressBar.track');

  static const Key fillKey = Key('osdProgressBar.fill');

  /// Progress, 0 to 1.
  final double value;

  /// Whether the movie is in its finishing phase.
  final bool finishing;

  @override
  State<OsdProgressBar> createState() => _OsdProgressBarState();
}

class _OsdProgressBarState extends State<OsdProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: OsdMotion.pulse,
    value: 1,
  );

  // Curved through a CurveTween: nothing to dispose besides the pulse.
  late final Animation<double> _opacity = _pulse.drive(
    Tween<double>(begin: .6, end: 1).chain(CurveTween(curve: Curves.easeInOut)),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(OsdProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.finishing && OsdMotion.loopsEnabled(context)) {
      if (!_pulse.isAnimating) unawaited(_pulse.repeat(reverse: true));
    } else {
      _pulse
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(4);
    return ExcludeSemantics(
      child: SizedBox(
        height: 8,
        child: DecoratedBox(
          key: OsdProgressBar.trackKey,
          decoration: BoxDecoration(color: colors.off, borderRadius: radius),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: widget.value.clamp(0, 1).toDouble()),
            duration: OsdMotion.d(context, OsdMotion.processing),
            curve: OsdMotion.curve(context, OsdMotion.processingCurve),
            builder: (context, value, _) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: value,
                heightFactor: 1,
                child: FadeTransition(
                  opacity: _opacity,
                  child: DecoratedBox(
                    key: OsdProgressBar.fillKey,
                    decoration: BoxDecoration(
                      color: colors.co,
                      borderRadius: radius,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
