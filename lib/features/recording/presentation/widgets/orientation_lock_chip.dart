import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/upright_rotation.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_camera.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The orientation lock over the preview: glass with white content while
/// auto-rotating, ink with dark content while locked. The glyph stays
/// upright as the phone turns; toggling crossfades the chip and its width
/// follows from the end edge. A toggled button for screen readers.
class OrientationLockChip extends StatelessWidget {
  const OrientationLockChip({
    super.key,
    required this.locked,
    required this.label,
    required this.icon,
    required this.semanticsLabel,
    required this.orientation,
    this.onPressed,
  });

  static const Key surfaceKey = Key('orientationLockChip.surface');

  static const double _minHeight = 44;
  static const double _glyph = 20;

  /// Whether the recording keeps the orientation it was locked in.
  final bool locked;

  /// "Auto-rotate", or "Locked · Landscape".
  final String label;

  final IconData icon;

  /// "Orientation: Auto-rotate" (a tap "changes" it, the tap hint says).
  final String semanticsLabel;

  /// How the phone is held (the glyph stays upright).
  final DeviceOrientation orientation;

  /// Toggles the lock; null turns the chip off.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Duration selection = OsdMotion.d(context, OsdMotion.selection);
    final Curve curve = OsdMotion.curve(context, OsdMotion.selectionCurve);
    final Color content = locked ? OsdCamera.inkForeground : OsdCamera.white;
    final Widget chip = OsdPressable(
      onTap: onPressed,
      pressScale: OsdMotion.pressScale(context, OsdPressScale.icon),
      overlay: OsdPressOverlay.none,
      borderRadius: BorderRadius.circular(OsdRadius.full),
      haptic: OsdHaptic.selection,
      semanticsLabel: semanticsLabel,
      // The platform says the gesture: "double-tap to change".
      semanticsTapHint: Strings.change,
      toggled: locked,
      excludeChildSemantics: true,
      child: AnimatedContainer(
        key: surfaceKey,
        duration: selection,
        curve: curve,
        constraints: const BoxConstraints(minHeight: _minHeight),
        padding: const EdgeInsetsDirectional.only(
          start: OsdSpace.s12,
          end: OsdSpace.s16,
        ),
        decoration: BoxDecoration(
          color: locked ? OsdCamera.ink : OsdCamera.glass,
          borderRadius: BorderRadius.circular(OsdRadius.full),
        ),
        child: AnimatedSize(
          duration: OsdMotion.d(context, OsdMotion.standard),
          curve: OsdMotion.curve(context, OsdMotion.standardCurve),
          alignment: AlignmentDirectional.centerEnd,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: OsdSpace.iconLabelGap,
            children: <Widget>[
              UprightRotation(
                orientation: orientation,
                child: AnimatedSwitcher(
                  duration: selection,
                  transitionBuilder: _turnIn,
                  child: TweenAnimationBuilder<Color?>(
                    key: ValueKey<IconData>(icon),
                    tween: ColorTween(end: content),
                    duration: selection,
                    builder: (BuildContext context, Color? color, _) =>
                        OsdIcon(icon, size: _glyph, color: color),
                  ),
                ),
              ),
              Flexible(
                child: AnimatedSwitcher(
                  duration: OsdMotion.d(context, OsdMotion.fast),
                  child: AnimatedDefaultTextStyle(
                    key: ValueKey<String>(label),
                    duration: selection,
                    style: context.typography.label14Strong.copyWith(
                      color: content,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: OsdTextScale.scalerFor(
                        context,
                        OsdTextScaleRole.mediaChrome,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Off at .4 through a wrapper that stays, so the chip keeps its state.
    return Opacity(
      opacity: onPressed == null ? OsdPressable.disabledOpacity : 1,
      child: chip,
    );
  }

  /// The incoming glyph turns in from −90° as it fades in; the outgoing one
  /// fades out.
  static Widget _turnIn(Widget child, Animation<double> animation) =>
      FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? child) => Transform.rotate(
            angle: animation.status == AnimationStatus.reverse
                ? 0
                : (animation.value - 1) * math.pi / 2,
            child: child,
          ),
          child: child,
        ),
      );
}
