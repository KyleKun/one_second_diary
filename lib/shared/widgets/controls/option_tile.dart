import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A single-choice tile: the [label] centred and scaled down to fit, in a
/// border that is inside the tile's height. Large text grows the tile.
///
/// A radio in a mutually exclusive group (`checked`).
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Key surfaceKey = Key('optionTile.surface');

  static const double _border = 1.5;
  static const double _height = 44;
  static const Duration _crossfade = Duration(milliseconds: 160);

  final String label;

  final bool selected;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final radius = BorderRadius.circular(OsdRadius.r12);
    return OsdPressable(
      onTap: onTap,
      haptic: OsdHaptic.selection,
      pressScale: OsdPressScale.button.scale,
      borderRadius: radius,
      isButton: false,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      semanticsLabel: label,
      excludeChildSemantics: true,
      child: AnimatedContainer(
        key: surfaceKey,
        duration: OsdMotion.d(context, _crossfade),
        curve: OsdMotion.curve(context, OsdMotion.selectionCurve),
        constraints: const BoxConstraints(
          minWidth: double.infinity,
          minHeight: _height,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? colors.sel : colors.sel.withValues(alpha: 0),
          border: Border.all(
            color: selected ? colors.tx : colors.off,
            width: _border,
          ),
          borderRadius: radius,
        ),
        child: Center(
          heightFactor: 1,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: (selected ? typography.label14Strong : typography.body14)
                  .copyWith(color: colors.tx),
            ),
          ),
        ),
      ),
    );
  }
}
