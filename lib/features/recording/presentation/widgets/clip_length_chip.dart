import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/upright_rotation.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_camera.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The camera's clip-length chip ("2 seconds"), its glyph turned upright
/// with the phone. A new length crossfades and the chip's width follows.
class ClipLengthChip extends StatelessWidget {
  const ClipLengthChip({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.orientation,
    this.onPressed,
  });

  static const Key surfaceKey = Key('clipLengthChip.surface');

  static const double _minHeight = 32;
  static const double _glyph = 18;

  /// "2 seconds".
  final String label;

  /// "Clip length, 2 seconds. Opens recording settings."
  final String semanticsLabel;

  /// How the phone is held (the glyph stays upright).
  final DeviceOrientation orientation;

  /// Opens the recording settings; null turns the chip off.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final Widget chip = OsdPressable(
      onTap: onPressed,
      pressScale: OsdMotion.pressScale(context, OsdPressScale.icon),
      overlay: OsdPressOverlay.none,
      borderRadius: BorderRadius.circular(OsdRadius.full),
      semanticsLabel: semanticsLabel,
      excludeChildSemantics: true,
      child: DecoratedBox(
        key: surfaceKey,
        decoration: BoxDecoration(
          color: OsdCamera.surface,
          borderRadius: BorderRadius.circular(OsdRadius.full),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: OsdSpace.s14),
            child: AnimatedSize(
              duration: OsdMotion.d(context, OsdMotion.standard),
              curve: OsdMotion.curve(context, OsdMotion.standardCurve),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: OsdSpace.chipIconGap,
                children: <Widget>[
                  UprightRotation(
                    orientation: orientation,
                    child: OsdIcon(
                      OsdIcons.timer,
                      size: _glyph,
                      color: colors.mu,
                    ),
                  ),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: OsdMotion.d(context, OsdMotion.fast),
                      child: Text(
                        label,
                        key: ValueKey<String>(label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textScaler: OsdTextScale.scalerFor(
                          context,
                          OsdTextScaleRole.mediaChrome,
                        ),
                        style: context.typography.label14.copyWith(
                          color: colors.tx,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
}
