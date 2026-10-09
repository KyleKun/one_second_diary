import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/osd_localization.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';

/// The app's translations, configured by [OsdLocalization]: every app root
/// (the app, the storage error state) mounts its `MaterialApp` below this,
/// taking `context.locale`, `context.supportedLocales` and
/// `context.localizationDelegates` from it.
class OsdLocalizationRoot extends StatelessWidget {
  /// [language] is the resolved app language (`LocaleResolver`): a
  /// supported one by construction, so easy_localization never tries to
  /// load a file the app does not have.
  const OsdLocalizationRoot({
    super.key,
    required this.language,
    required this.child,
    this.assetLoader = const RootBundleAssetLoader(),
  });

  /// The language the app starts in.
  final AppLanguage language;
  final Widget child;

  /// Reads `<languageCode>.json` from [OsdLocalization.path]: the bundled
  /// assets. Tests pass fixtures (plural keys the app has no text for yet).
  final AssetLoader assetLoader;

  @override
  Widget build(BuildContext context) {
    return EasyLocalization(
      supportedLocales: OsdLocalization.supportedLocales,
      path: OsdLocalization.path,
      fallbackLocale: OsdLocalization.fallbackLocale,
      startLocale: OsdLocalization.localeOf(language),
      useOnlyLangCode: OsdLocalization.useOnlyLangCode,
      useFallbackTranslations: OsdLocalization.useFallbackTranslations,
      ignorePluralRules: OsdLocalization.ignorePluralRules,
      saveLocale: OsdLocalization.saveLocale,
      assetLoader: assetLoader,
      child: child,
    );
  }
}
