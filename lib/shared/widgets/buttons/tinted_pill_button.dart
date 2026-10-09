import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_tints.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The coral-tinted chip: a stadium with a filled icon and a label.
///
/// It collapses to an icon-only circle (keeping the label as tooltip and
/// semantics) when [iconOnly], when its slot is narrower than
/// [iconOnlyBelowWidth], or at large text scales. In a `Row` beside other
/// content its slot is unbounded: the row's owner measures [labelledWidth]
/// and passes [iconOnly]. [onDisabledTap] still hears the tap when disabled.
class TintedPillButton extends StatelessWidget {
  const TintedPillButton({
    super.key,
    required this.label,
    this.icon = OsdIcons.movie,
    this.onPressed,
    this.onDisabledTap,
    this.iconOnly = false,
  });

  static const Key surfaceKey = Key('tintedPillButton.surface');

  /// Below this slot width the chip goes icon-only.
  static const double iconOnlyBelowWidth = 110;

  static const double _padding = 12;
  static const double _glyph = 18;
  static const double _gap = 6;

  /// How wide the labelled pill of [label] is drawn in [context] (its text
  /// scale and typography): a row that sits the chip beside other content
  /// (a `Row` gives it unbounded width) decides [iconOnly] with it.
  static double labelledWidth(BuildContext context, String label) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: label, style: context.typography.label14Strong),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final double text = painter.width;
    painter.dispose();
    return 2 * _padding + _glyph + _gap + text.ceilToDouble();
  }

  final String label;

  final IconData icon;

  /// Called on tap; null disables the chip.
  final VoidCallback? onPressed;

  /// Called when the disabled chip is tapped.
  final VoidCallback? onDisabledTap;

  /// Forces the icon-only circle.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final collapsed =
          iconOnly ||
          constraints.maxWidth < iconOnlyBelowWidth ||
          OsdTextScale.factorOf(context) >= OsdTextScale.iconOnlyChipFrom;
      final colors = context.colors;
      final glyph = OsdIcon(icon, size: _glyph, fill: 1, color: colors.coInk);
      final Widget chip = collapsed
          ? Center(
              widthFactor: 1,
              heightFactor: 1,
              child: SizedBox.square(
                key: surfaceKey,
                dimension: 38,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: OsdTints.coTint14,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: glyph),
                ),
              ),
            )
          : DecoratedBox(
              key: surfaceKey,
              decoration: BoxDecoration(
                color: OsdTints.coTint14,
                borderRadius: BorderRadius.circular(OsdRadius.full),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _padding,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: _gap,
                  children: <Widget>[
                    glyph,
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.label14Strong.copyWith(
                          color: colors.coInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
      final enabled = onPressed != null;
      final pressable = OsdPressable(
        opacity: OsdPressable.opacityFor(enabled: enabled),
        onTap: onPressed,
        onDisabledTap: onDisabledTap,
        pressScale: OsdPressScale.button.scale,
        overlay: OsdPressOverlay.none,
        shape: collapsed ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: BorderRadius.circular(OsdRadius.full),
        tooltip: collapsed ? label : null,
        child: chip,
      );
      return pressable;
    },
  );
}
