import 'package:flutter/widgets.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';

import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// A [side] wide C2 disc around [child], the size of a camera app's side
/// buttons: Today's Import and Character buttons beside Record. One
/// semantics node, [semanticsLabel]; it fades when disabled.
class RoundDiscButton extends StatelessWidget {
  const RoundDiscButton({
    super.key,
    required this.semanticsLabel,
    required this.onPressed,
    required this.child,
    this.side = 60,
  });

  final String semanticsLabel;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final Widget child;
  final double side;

  @override
  Widget build(BuildContext context) => OsdPressable(
    onTap: onPressed,
    opacity: OsdPressable.opacityFor(enabled: onPressed != null),
    pressScale: OsdPressScale.icon.scale,
    overlay: OsdPressOverlay.none,
    shape: BoxShape.circle,
    borderRadius: BorderRadius.circular(side / 2),
    semanticsLabel: semanticsLabel,
    excludeChildSemantics: true,
    child: Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.c2,
      ),
      child: Center(child: child),
    ),
  );
}
