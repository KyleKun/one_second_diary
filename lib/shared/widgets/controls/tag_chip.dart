import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A tag: a stadium tinted with the tag's [color], a dot of it and the
/// name. Three uses:
///
/// - read-only ([onTap] and [onRemove] null), under a clip's caption;
/// - selectable ([onTap], [selected]), in a filter: a selected chip fills
///   with its colour;
/// - editable ([onRemove]), in the tags sheet: a small × removes it.
///
/// [compact] is the caption size (smaller text, tighter padding).
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    required this.color,
    this.selected = false,
    this.compact = false,
    this.onTap,
    this.onRemove,
    this.semanticsLabel,
    this.removeSemanticsLabel,
  });

  static const Key surfaceKey = Key('tagChip.surface');
  static const Key removeKey = Key('tagChip.remove');

  final String label;

  /// The tag's colour (`TagColors.colorOf`).
  final Color color;

  final bool selected;
  final bool compact;
  final VoidCallback? onTap;

  /// Shows a × that calls this.
  final VoidCallback? onRemove;

  final String? semanticsLabel;
  final String? removeSemanticsLabel;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final Duration duration = OsdMotion.d(context, OsdMotion.selection);
    final Curve curve = OsdMotion.curve(context, OsdMotion.selectionCurve);
    final Color ink = selected ? colors.bg : colors.tx;
    final Color fill = selected ? color : color.withValues(alpha: .16);
    final TextStyle style =
        (compact ? typography.label13 : typography.chipLabel).copyWith(
          color: ink,
        );
    final Widget body = AnimatedContainer(
      key: surfaceKey,
      duration: duration,
      curve: curve,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(OsdRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: compact ? 5 : 6,
        children: <Widget>[
          if (!selected)
            Container(
              width: compact ? 6 : 8,
              height: compact ? 6 : 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (onRemove != null)
            OsdPressable(
              key: removeKey,
              onTap: onRemove,
              haptic: OsdHaptic.light,
              shape: BoxShape.circle,
              overlay: OsdPressOverlay.none,
              minHitSize: 32,
              semanticsLabel: removeSemanticsLabel,
              child: OsdIcon(
                OsdIcons.close,
                size: compact ? 13 : 15,
                color: ink,
              ),
            ),
        ],
      ),
    );
    if (onTap == null) {
      return Semantics(label: semanticsLabel, child: body);
    }
    return OsdPressable(
      onTap: onTap,
      haptic: OsdHaptic.selection,
      pressScale: OsdPressScale.actionTile.scale,
      overlay: OsdPressOverlay.none,
      borderRadius: BorderRadius.circular(OsdRadius.full),
      selected: selected,
      semanticsLabel: semanticsLabel ?? label,
      excludeChildSemantics: true,
      child: body,
    );
  }
}
