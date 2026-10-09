import 'package:flutter/widgets.dart';

/// Reduced motion means either platform setting: Android's "remove
/// animations" (`AccessibilityFeatures.disableAnimations`) or iOS Reduce
/// Motion (`AccessibilityFeatures.reduceMotion`, which Flutter 3.47 keeps
/// out of `MediaQueryData`).
///
/// This folds the iOS setting into `MediaQueryData.disableAnimations` for
/// everything below, once, at the app root, so `OsdMotion`, the page
/// transitions and every widget that honours
/// `MediaQuery.disableAnimationsOf` follow it. It rebuilds when the phone
/// changes the setting (`didChangeAccessibilityFeatures`, which the binding
/// calls from `PlatformDispatcher.onAccessibilityFeaturesChanged`), and the
/// widgets below keep their state.
class PlatformReducedMotion extends StatefulWidget {
  const PlatformReducedMotion({super.key, required this.child});

  final Widget child;

  @override
  State<PlatformReducedMotion> createState() => _PlatformReducedMotionState();
}

class _PlatformReducedMotionState extends State<PlatformReducedMotion>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final MediaQueryData data = MediaQuery.of(context);
    final bool reduceMotion = View.of(
      context,
    ).platformDispatcher.accessibilityFeatures.reduceMotion;
    return MediaQuery(
      data: data.copyWith(
        disableAnimations: data.disableAnimations || reduceMotion,
      ),
      child: widget.child,
    );
  }
}
