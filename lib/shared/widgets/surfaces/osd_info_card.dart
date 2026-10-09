import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_spinner.dart';
import 'package:one_second_diary/theme/light_hairline.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_surface.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A label/value card of the clip editor: a leading (an avatar, swatch or
/// icon), a label over a value, and an optional trailing (a pill, a chevron,
/// a switch, a clear button).
///
/// - The value takes [valueMaxLines] lines, then ellipsizes; at large text
///   scales at least three.
/// - [loading] turns the value MU and crossfades a spinner in place of the
///   leading.
/// - With [onTap] the card is one button, "label, value". An interactive
///   trailing keeps its own node.
class OsdInfoCard extends StatelessWidget {
  const OsdInfoCard({
    super.key,
    required this.leading,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
    this.valueMuted = false,
    this.loading = false,
    this.valueMaxLines = 1,
  });

  static const Key surfaceKey = Key('osdInfoCard.surface');

  static const Key valueKey = Key('osdInfoCard.value');

  static const Key spinnerKey = Key('osdInfoCard.spinner');

  final Widget leading;

  final String label;

  final String value;

  final Widget? trailing;

  final VoidCallback? onTap;

  /// Whether the value is drawn in MU.
  final bool valueMuted;

  /// Whether the value is being found.
  final bool loading;

  /// The lines the value takes before its ellipsis, at normal text sizes.
  final int valueMaxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final radius = BorderRadius.circular(OsdRadius.r18);
    final trailing = this.trailing;
    // At large text scales (where a row's value moves under its title) they
    // wrap rather than lose their end.
    final bool wrap =
        OsdTextScale.factorOf(context) >= OsdTextScale.valuesUnderTitleFrom;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        spacing: 12,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: AnimatedSwitcher(
              duration: OsdMotion.d(context, OsdMotion.fast),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.center,
                children: <Widget>[...previous, ?current],
              ),
              child: loading
                  ? Stack(
                      key: const ValueKey<bool>(true),
                      alignment: Alignment.center,
                      children: <Widget>[
                        Visibility.maintain(visible: false, child: leading),
                        OsdSpinner(key: spinnerKey, size: 14, color: colors.mu),
                      ],
                    )
                  : KeyedSubtree(
                      key: const ValueKey<bool>(false),
                      child: leading,
                    ),
            ),
          ),
          Expanded(
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: wrap ? null : 1,
                      overflow: wrap ? null : TextOverflow.ellipsis,
                      style: typography.caption.copyWith(color: colors.mu),
                    ),
                    Text(
                      value,
                      key: valueKey,
                      maxLines: wrap
                          ? (valueMaxLines > 3 ? valueMaxLines : 3)
                          : valueMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: typography.titleSmall.copyWith(
                        color: valueMuted || loading ? colors.mu : colors.tx,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (trailing != null)
            OsdSurface(tone: OsdSurfaceTone.card, child: trailing),
        ],
      ),
    );
    final card = LightHairline(
      radius: radius,
      child: DecoratedBox(
        key: surfaceKey,
        decoration: BoxDecoration(color: colors.card, borderRadius: radius),
        child: content,
      ),
    );
    if (onTap == null) {
      return Semantics(container: true, label: '$label, $value', child: card);
    }
    return OsdPressable(
      onTap: onTap,
      pressScale: OsdPressScale.infoCard.scale,
      borderRadius: radius,
      semanticsLabel: '$label, $value',
      child: card,
    );
  }
}
