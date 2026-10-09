import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Brings a piece of the camera's chrome in over the last `OsdMotion.fast`
/// of the page's entrance, once Today's record button has nearly landed on
/// the shutter; it goes first when the page leaves. Under reduced motion it
/// only fades.
class CameraEntrance extends StatelessWidget {
  const CameraEntrance({super.key, required this.child, this.scaleFrom = 1});

  final Widget child;

  /// The scale it grows from.
  final double scaleFrom;

  @override
  Widget build(BuildContext context) {
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    final Animation<double>? entrance = route?.animation;
    if (route == null || entrance == null) return child;
    final int length = route.transitionDuration.inMicroseconds;
    final int fade = OsdMotion.fast.inMicroseconds;
    // Built on every rebuild (and every route change): a CurveTween keeps no
    // listener of its own on the route's animation, where a CurvedAnimation
    // made here would leak one.
    final Animation<double> shown = entrance.drive(
      CurveTween(
        curve: Interval(
          length <= fade ? 0 : 1 - fade / length,
          1,
          curve: OsdMotion.fastCurve,
        ),
      ),
    );
    final Widget faded = FadeTransition(opacity: shown, child: child);
    if (scaleFrom == 1 || OsdMotion.reduced(context)) return faded;
    return ScaleTransition(
      scale: Tween<double>(begin: scaleFrom, end: 1).animate(shown),
      child: faded,
    );
  }
}
