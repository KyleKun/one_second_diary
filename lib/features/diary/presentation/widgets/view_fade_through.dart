import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The Diary's Calendar ↔ Memories switch: a fade-through, the old view
/// fading out first, then the new one fading in while it grows. Under
/// reduced motion, a crossfade. Give each view a distinct key.
class ViewFadeThrough extends StatelessWidget {
  const ViewFadeThrough({super.key, required this.child});

  final Widget child;

  static final double _split =
      OsdMotion.viewSwitchOut.inMicroseconds /
      OsdMotion.viewSwitch.inMicroseconds;

  @override
  Widget build(BuildContext context) {
    final bool reduced = OsdMotion.reduced(context);
    final Key? current = child.key;
    return AnimatedSwitcher(
      duration: OsdMotion.d(context, OsdMotion.viewSwitch),
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        fit: StackFit.expand,
        children: <Widget>[...previous, ?current],
      ),
      // A new closure each build: the old view's transition is rebuilt as
      // the one leaving. Both keep the same widgets around the view, so it
      // is never built again from scratch (its players keep playing).
      transitionBuilder: (Widget view, Animation<double> animation) {
        final bool leaving = view.key != current;
        final Animation<double> opacity = reduced
            ? animation
            : animation.drive(
                CurveTween(
                  curve: leaving
                      ? Interval(1 - _split, 1, curve: OsdMotion.fastCurve)
                      : Interval(_split, 1, curve: OsdMotion.standardCurve),
                ),
              );
        return FadeTransition(
          opacity: opacity,
          child: ScaleTransition(
            scale: reduced || leaving
                ? kAlwaysCompleteAnimation
                : Tween<double>(
                    begin: OsdMotion.viewSwitchScale,
                    end: 1,
                  ).animate(opacity),
            child: view,
          ),
        );
      },
      child: child,
    );
  }
}
