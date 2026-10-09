import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A quick-cut chip of the clip editor: a stadium holding a scissors glyph
/// and the length in seconds, formatted for the locale ("1,5" in de).
/// Disabled when longer than the source.
class QuickCutChip extends StatelessWidget {
  const QuickCutChip({
    super.key,
    required this.seconds,
    required this.selected,
    this.enabled = true,
    required this.onTap,
    required this.semanticsLabel,
  });

  static const Key surfaceKey = Key('quickCutChip.surface');

  /// The length this chip trims to.
  final double seconds;

  /// Whether the current trim has this length.
  final bool selected;

  /// False when the source is shorter than [seconds].
  final bool enabled;

  final VoidCallback? onTap;

  final String semanticsLabel;

  static String _format(double seconds, Locale locale) =>
      LocaleFormats.forLocale(locale.toLanguageTag()).numbers.format(seconds);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final duration = OsdMotion.d(context, OsdMotion.selection);
    final curve = OsdMotion.curve(context, OsdMotion.selectionCurve);
    final ink = !enabled
        ? colors.dis
        : selected
        ? colors.bg
        : colors.tx;
    return OsdPressable(
      onTap: enabled ? onTap : null,
      haptic: OsdHaptic.selection,
      pressScale: OsdPressScale.actionTile.scale,
      overlay: OsdPressOverlay.none,
      borderRadius: BorderRadius.circular(OsdRadius.full),
      selected: selected,
      semanticsLabel: semanticsLabel,
      excludeChildSemantics: true,
      child: AnimatedContainer(
        key: surfaceKey,
        duration: duration,
        curve: curve,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected && enabled ? colors.tx : colors.btn,
          borderRadius: BorderRadius.circular(OsdRadius.full),
        ),
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: ink),
          duration: duration,
          curve: curve,
          builder: (context, color, _) => Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: <Widget>[
              OsdIcon(OsdIcons.contentCut, size: 15, color: color),
              Text(
                _format(seconds, Localizations.localeOf(context)),
                maxLines: 1,
                style: (selected ? typography.sectionLabel : typography.label13)
                    .copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
