import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The page transitions of `OsdTheme`.
///
/// A `MaterialPageRoute` (and every go_router page) reads its builder and
/// its duration from the navigator's theme when it is pushed, so the app
/// theme picks [reducedMotion] while the platform asks for it.
abstract final class OsdPageTransitions {
  /// Platform pushes keep the system back gestures. Route replacements use
  /// a fade-through and media flights a Hero, built per route.
  static const PageTransitionsTheme platform = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );

  /// Reduced motion: every push and pop is a crossfade of
  /// [OsdMotion.reducedMax], on every platform.
  static const PageTransitionsTheme reducedMotion = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: OsdCrossfadePageTransitionsBuilder(
        PredictiveBackPageTransitionsBuilder(),
      ),
      TargetPlatform.iOS: OsdCrossfadePageTransitionsBuilder(
        CupertinoPageTransitionsBuilder(),
      ),
      TargetPlatform.macOS: OsdCrossfadePageTransitionsBuilder(
        CupertinoPageTransitionsBuilder(),
      ),
      TargetPlatform.fuchsia: OsdCrossfadePageTransitionsBuilder(
        ZoomPageTransitionsBuilder(),
      ),
      TargetPlatform.linux: OsdCrossfadePageTransitionsBuilder(
        ZoomPageTransitionsBuilder(),
      ),
      TargetPlatform.windows: OsdCrossfadePageTransitionsBuilder(
        ZoomPageTransitionsBuilder(),
      ),
    },
  );
}

/// A linear crossfade of [OsdMotion.reducedMax] for pushes and pops: no
/// slide, zoom or parallax, and the page below stays still.
///
/// The [platform] builder still builds the page, held at rest, so its back
/// gesture (the iOS edge swipe, Android predictive back) keeps popping the
/// route; the gesture then drives the fade.
class OsdCrossfadePageTransitionsBuilder extends PageTransitionsBuilder {
  const OsdCrossfadePageTransitionsBuilder(this.platform);

  /// The platform's builder, for its back gesture.
  final PageTransitionsBuilder platform;

  @override
  Duration get transitionDuration => OsdMotion.reducedMax;

  @override
  Duration get reverseTransitionDuration => OsdMotion.reducedMax;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => null;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: animation,
    child: platform.buildTransitions<T>(
      route,
      context,
      kAlwaysCompleteAnimation,
      kAlwaysDismissedAnimation,
      child,
    ),
  );
}
