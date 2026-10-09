import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Shows or hides a piece of the camera's chrome: it fades over
/// [duration], rising by [rise] px or shrinking to [shrink] on the way out.
/// Hidden, it takes no taps and says nothing. Under reduced motion it only
/// fades.
class CameraChromeFade extends StatelessWidget {
  const CameraChromeFade({
    super.key,
    required this.visible,
    required this.child,
    this.duration = OsdMotion.fast,
    this.rise = 0,
    this.shrink = 1,
  });

  final bool visible;

  final Widget child;

  final Duration duration;

  /// How far it rises as it leaves.
  final double rise;

  /// The scale it shrinks to as it leaves.
  final double shrink;

  @override
  Widget build(BuildContext context) {
    final bool reduced = OsdMotion.reduced(context);
    final Duration length = OsdMotion.d(context, duration);
    final Curve curve = OsdMotion.curve(
      context,
      visible ? OsdMotion.fastCurve : Curves.easeIn,
    );
    Widget result = AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: length,
      curve: curve,
      child: child,
    );
    if (!reduced && (rise != 0 || shrink != 1)) {
      result = TweenAnimationBuilder<double>(
        tween: Tween<double>(end: visible ? 0 : 1),
        duration: length,
        curve: curve,
        builder: (BuildContext context, double away, Widget? child) =>
            Transform.translate(
              offset: Offset(0, -rise * away),
              child: Transform.scale(
                scale: 1 - (1 - shrink) * away,
                child: child,
              ),
            ),
        child: result,
      );
    }
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(excluding: !visible, child: result),
    );
  }
}
