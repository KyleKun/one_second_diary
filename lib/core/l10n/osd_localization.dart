import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/domain/locale_resolver.dart';

/// The easy_localization configuration for the app.
///
/// The app root mounts `EasyLocalization` with every setting below and a
/// `startLocale` of [localeOf] the resolved app language; its `MaterialApp`
/// takes `locale`, `supportedLocales` and `localizationDelegates` from the
/// context, which also localises the Material widgets. Widgets read text
/// through `Strings`.
///
/// There is one resolution path: `LocaleResolver` picks the
/// [AppLanguage] (the `lang` preference when supported, else the device
/// language when supported, else English), and [localeOf] turns it into the
/// locale easy_localization and intl see. A language the app has no
/// translation for can't be an [AppLanguage], so it never reaches them.
abstract final class OsdLocalization {
  /// The locale of [language]: language-only, as `useOnlyLangCode` loads
  /// `<code>.json`.
  static Locale localeOf(AppLanguage language) => Locale(language.code);

  /// Makes [language] intl's default locale, so a `DateFormat` or
  /// `NumberFormat` given no locale formats in the app language.
  ///
  /// `EasyLocalization.ensureInitialized` puts the phone's raw locale in
  /// `Intl.systemLocale`, which intl uses when no default is set: the
  /// phone's formats under another app language, and a locale intl has no
  /// data for (`jv_ID`) throws. Call it once the language is resolved at
  /// launch and again on every language change.
  static void applyToIntl(AppLanguage language) =>
      Intl.defaultLocale = localeOf(language).toLanguageTag();

  /// The 12 app languages ([AppLanguage]), language-only.
  ///
  /// English comes first on purpose: Flutter's default locale resolution
  /// picks the first supported locale when nothing matches, so an unsupported
  /// language lands on English rather than Belarusian.
  static final List<Locale> supportedLocales =
      List<Locale>.unmodifiable(<Locale>[
        fallbackLocale,
        for (final AppLanguage language in AppLanguage.values)
          if (language != LocaleResolver.fallback) localeOf(language),
      ]);

  /// The asset folder that holds `<languageCode>.json` per language.
  static const String path = 'assets/translations';

  /// The language used when nothing matches, and per key when the current
  /// language lacks a key (`LocaleResolver.fallback`).
  static final Locale fallbackLocale = localeOf(LocaleResolver.fallback);

  /// Load `pt.json`, never `pt-BR.json`.
  static const bool useOnlyLangCode = true;

  /// A key missing from the current language shows the English text instead
  /// of the raw key.
  static const bool useFallbackTranslations = true;

  /// Use each language's CLDR plural rules (few / many for ru, be, cs).
  static const bool ignorePluralRules = false;

  /// easy_localization must not persist its own `locale` pref: the app keeps
  /// the `lang` pref as the single source of truth.
  static const bool saveLocale = false;
}
