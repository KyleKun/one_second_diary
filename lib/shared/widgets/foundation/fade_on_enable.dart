import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// A control that fades on (from `OsdPressable.disabledOpacity` to 1 over
/// `OsdMotion.fast`) when it turns on. The shared controls dim themselves
/// while off and jump back to 1; this holds the jump back, so the change
/// reads as a fade. Turning off stays at once, and so does turning on under
/// reduced motion.
class FadeOnEnable extends StatefulWidget {
  const FadeOnEnable({super.key, required this.enabled, required this.child});

  /// Whether [child] is on (it dims itself while off).
  final bool enabled;

  final Widget child;

  @override
  State<FadeOnEnable> createState() => _FadeOnEnableState();
}

class _FadeOnEnableState extends State<FadeOnEnable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: OsdMotion.fast,
    value: 1,
  );

  @override
  void didUpdateWidget(FadeOnEnable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled || !widget.enabled || OsdMotion.reduced(context)) {
      return;
    }
    _fade.value = OsdPressable.disabledOpacity;
    unawaited(_fade.animateTo(1, curve: OsdMotion.fastCurve));
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _fade, child: widget.child);
}
