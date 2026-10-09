import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Swaps its [child] with a pop: the new child fades in and scales
/// [fromScale] → 1 over [duration]; the old one fades and shrinks back over
/// [reverseDuration].
///
/// Give each state's child its own key. Under reduced motion it is a plain
/// fade.
class OsdPopSwitcher extends StatelessWidget {
  const OsdPopSwitcher({
    super.key,
    required this.child,
    this.duration = OsdMotion.badgeIn,
    this.reverseDuration = _out,
    this.fromScale = OsdMotion.badgeInScale,
  });

  static const Duration _out = Duration(milliseconds: 120);

  /// The current state (null shows nothing).
  final Widget? child;

  final Duration duration;

  final Duration reverseDuration;

  /// The scale a new child starts from.
  final double fromScale;

  @override
  Widget build(BuildContext context) {
    final reduced = OsdMotion.reduced(context);
    return AnimatedSwitcher(
      duration: OsdMotion.d(context, duration),
      reverseDuration: OsdMotion.d(context, reverseDuration),
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      // AnimatedSwitcher calls this again on every rebuild: curves made
      // here keep no listener (no CurvedAnimation, which would never be
      // disposed).
      transitionBuilder: (child, animation) {
        final fade = FadeTransition(
          opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
          child: child,
        );
        if (reduced) return fade;
        return _PopScale(animation: animation, from: fromScale, child: fade);
      },
      child: child,
    );
  }
}

/// [child] scaled from [from] to 1 as [animation] runs: `badgeInCurve` on
/// the way in, `easeIn` on the way out.
class _PopScale extends AnimatedWidget {
  const _PopScale({
    required Animation<double> animation,
    required this.from,
    required this.child,
  }) : super(listenable: animation);

  final double from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final curve = animation.status == AnimationStatus.reverse
        ? Curves.easeIn
        : OsdMotion.badgeInCurve;
    return Transform.scale(
      scale: from + (1 - from) * curve.transform(animation.value),
      child: child,
    );
  }
}
