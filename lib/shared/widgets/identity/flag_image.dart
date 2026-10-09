import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jovial_svg/jovial_svg.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A language's flag, under an inset OUTLINE hairline so white flag areas
/// don't bleed into light surfaces.
///
/// The artwork is bundled in `assets/flags/` (vectors, never emoji): the
/// flag-icons flags as the `country_flags` package compiled them, one per
/// language. While it loads, and for a code with no bundled flag, the rect is
/// C2; a code with no flag also shows [fallbackLabel] (the language code).
/// Decorative: the language name is always next to it.
class FlagImage extends StatelessWidget {
  const FlagImage({
    super.key,
    required this.countryCode,
    required this.fallbackLabel,
  });

  /// The rounded rect with its hairline.
  static const Key surfaceKey = Key('flagImage.surface');

  static const Size size = Size(28, 20);

  /// The ISO 3166 codes of the bundled flags: one per `AppLanguage`.
  static const Set<String> bundledCountryCodes = <String>{
    'AD',
    'BR',
    'BY',
    'CN',
    'CZ',
    'DE',
    'ES',
    'FR',
    'HU',
    'ID',
    'RU',
    'US',
  };

  /// The licence of the bundled flag artwork (flag-icons and
  /// `country_flags`, both MIT).
  static const String licenseAsset = 'assets/flags/LICENSE.txt';

  /// The bundled artwork of [countryCode], or null when there is none.
  static String? assetFor(String countryCode) {
    final code = countryCode.toUpperCase();
    if (!bundledCountryCodes.contains(code)) return null;
    return 'assets/flags/${code.toLowerCase()}.si';
  }

  /// The ISO 3166 code of the flag ("DE", "AD").
  final String countryCode;

  /// Shown when there is no flag for [countryCode].
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(OsdRadius.r4);
    final asset = assetFor(countryCode);
    return ExcludeSemantics(
      child: SizedBox.fromSize(
        size: size,
        child: DecoratedBox(
          key: surfaceKey,
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(color: colors.outline),
            borderRadius: radius,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: ColoredBox(
              color: colors.c2,
              child: asset != null
                  ? ScalableImageWidget.fromSISource(
                      si: ScalableImageSource.fromSI(rootBundle, asset),
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Text(
                        fallbackLabel.toUpperCase(),
                        maxLines: 1,
                        textScaler: TextScaler.noScaling,
                        style: context.typography.microBadge.copyWith(
                          fontSize: 10,
                          color: colors.mu,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
