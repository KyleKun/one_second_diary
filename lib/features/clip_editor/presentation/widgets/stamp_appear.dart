import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// How a place or a subtitle comes onto the preview: it rises as it fades
/// in, and fades out. Under reduced motion both are plain fades.
///
/// Give it the stamp, or null for none; a stamp with another key replaces
/// the old one the same way.
class StampAppear extends StatelessWidget {
  const StampAppear({
    super.key,
    required this.child,
    this.alignment = Alignment.bottomCenter,
  });

  /// How long a stamp takes to come in.
  static const Duration appear = Duration(milliseconds: 200);

  /// How far it rises as it comes in.
  static const double rise = 4;

  /// The stamp, or null.
  final Widget? child;

  /// Where the stamp sits while one replaces another.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final bool reduced = OsdMotion.reduced(context);
    return AnimatedSwitcher(
      duration: OsdMotion.d(context, appear),
      reverseDuration: OsdMotion.d(context, OsdMotion.fast),
      switchInCurve: OsdMotion.curve(context, OsdMotion.fastCurve),
      switchOutCurve: OsdMotion.curve(context, OsdMotion.fastCurve),
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: alignment,
        clipBehavior: Clip.none,
        children: <Widget>[...previous, ?current],
      ),
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(
            opacity: animation,
            child: reduced ? child : _Rise(animation: animation, child: child),
          ),
      child: child,
    );
  }
}

/// Lifts [child] by what is left of [animation] while it comes in; a stamp
/// on its way out stays where it is.
class _Rise extends AnimatedWidget {
  const _Rise({required Animation<double> animation, required this.child})
    : super(listenable: animation);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Animation<double> animation = listenable as Animation<double>;
    final bool coming = animation.status == AnimationStatus.forward;
    return Transform.translate(
      offset: Offset(0, coming ? StampAppear.rise * (1 - animation.value) : 0),
      child: child,
    );
  }
}
