import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pop_switcher.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/identity/flag_image.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A language in the language sheet: a [FlagImage], the [endonym] drawn in
/// its own [locale], and a check when selected.
///
/// Semantics: a button, `selected`, mutually exclusive, whose label carries a
/// `LocaleStringAttribute` so screen readers speak it in its own language.
class LanguageRow extends StatelessWidget {
  const LanguageRow({
    super.key,
    required this.endonym,
    required this.locale,
    required this.countryCode,
    required this.selected,
    required this.onTap,
  });

  static const Key surfaceKey = Key('languageRow.surface');

  static const Key checkKey = Key('languageRow.check');

  static const Duration _fade = Duration(milliseconds: 160);

  /// The language's own name ("Deutsch", "中文").
  final String endonym;

  final Locale locale;

  /// The flag's ISO 3166 code.
  final String countryCode;

  /// Whether this is the app language.
  final bool selected;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final radius = BorderRadius.circular(OsdRadius.r14);
    return OsdPressable(
      onTap: onTap,
      haptic: OsdHaptic.selection,
      pressScale: null,
      borderRadius: radius,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: AnimatedContainer(
        key: surfaceKey,
        duration: OsdMotion.d(context, _fade),
        curve: OsdMotion.curve(context, OsdMotion.fastCurve),
        constraints: const BoxConstraints(
          minHeight: OsdSizes.languageRowHeight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? colors.sel : colors.sel.withValues(alpha: 0),
          borderRadius: radius,
        ),
        child: Row(
          spacing: 14,
          children: <Widget>[
            FlagImage(
              countryCode: countryCode,
              fallbackLabel: locale.languageCode,
            ),
            Expanded(
              child: Semantics(
                attributedLabel: AttributedString(
                  endonym,
                  attributes: <StringAttribute>[
                    LocaleStringAttribute(
                      range: TextRange(start: 0, end: endonym.length),
                      locale: locale,
                    ),
                  ],
                ),
                child: ExcludeSemantics(
                  child: Text(
                    endonym,
                    locale: locale,
                    // "Bahasa Indonesia" at a large text size: the row
                    // grows rather than cut the name.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (selected
                                ? typography.langNameSelected
                                : typography.langName)
                            .copyWith(color: colors.tx),
                  ),
                ),
              ),
            ),
            OsdPopSwitcher(
              child: selected
                  ? OsdIcon(OsdIcons.check, key: checkKey, color: colors.tx)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
