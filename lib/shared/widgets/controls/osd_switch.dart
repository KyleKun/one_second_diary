import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';

/// The app's switch. Material's switch is the wrong size, so this one is
/// drawn.
///
/// - **Standalone** ([interactive]): its own hit area and `toggled`
///   semantics; disabled without [onChanged].
/// - **Inside a row** (`interactive: false`): only the visual. The row owns
///   the gesture and the `toggled` flag, so there is one target.
class OsdSwitch extends StatelessWidget {
  const OsdSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.interactive = true,
    this.semanticsLabel,
  });

  static const Key trackKey = Key('osdSwitch.track');

  static const Key thumbKey = Key('osdSwitch.thumb');

  static const double _radius = 13;
  static const double _inset = 3;
  static const double _thumb = 20;

  final bool value;

  /// Called with the new value; null disables a standalone switch.
  final ValueChanged<bool>? onChanged;

  /// False inside rows: the switch only draws.
  final bool interactive;

  /// The semantics label of a standalone switch.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final duration = OsdMotion.d(context, OsdMotion.selection);
    final curve = OsdMotion.curve(context, OsdMotion.switchCurve);
    final visual = AnimatedContainer(
      key: trackKey,
      duration: duration,
      curve: curve,
      width: OsdSizes.switchSize.width,
      height: OsdSizes.switchSize.height,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: value ? colors.tx : colors.off,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: curve,
        alignment: value
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: AnimatedContainer(
          key: thumbKey,
          duration: duration,
          curve: curve,
          width: _thumb,
          height: _thumb,
          decoration: BoxDecoration(
            color: value ? colors.bg : colors.mu,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
    if (!interactive) return visual;

    final onChanged = this.onChanged;
    final pressable = OsdPressable(
      opacity: OsdPressable.opacityFor(enabled: onChanged != null),
      onTap: onChanged == null ? null : () => onChanged(!value),
      haptic: OsdHaptic.selection,
      pressScale: null,
      overlay: OsdPressOverlay.none,
      borderRadius: BorderRadius.circular(_radius),
      isButton: false,
      toggled: value,
      semanticsLabel: semanticsLabel,
      child: visual,
    );
    return pressable;
  }
}
