import 'package:flutter/widgets.dart';

/// [child] fading in and rising [rise] px into place as [animation] runs
/// 0 → 1. Give it an animation already curved and staggered
/// (`parent.drive(CurveTween(curve: Interval(…)))`, which keeps no listener
/// of its own).
///
/// The rise is a paint-only translate, so nothing lays out again. Under
/// reduced motion pass a [rise] of 0: the child only fades.
class FadeRise extends StatelessWidget {
  const FadeRise({
    super.key,
    required this.animation,
    required this.rise,
    required this.child,
  });

  final Animation<double> animation;

  /// How far below its place the child starts, in logical px.
  final double rise;

  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: animation,
    child: rise == 0
        ? child
        : AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) =>
                Transform.translate(
                  offset: Offset(0, rise * (1 - animation.value)),
                  child: child,
                ),
            child: child,
          ),
  );
}
