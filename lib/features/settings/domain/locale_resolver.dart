import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/domain/language_catalog.dart';

/// Picks the language the app runs in.
///
/// The result is always a supported [AppLanguage], so the localisation, the
/// date formats, the calendar and the geocoder only ever see one of the
/// app's 12 codes.
///
/// A language the user did not pick is never stored, and an unsupported
/// stored value (older installs stored the device language, supported or
/// not) counts as unset, so the app keeps following the device.
abstract final class LocaleResolver {
  /// The language used when neither the user nor the device picks a
  /// supported one.
  static const AppLanguage fallback = AppLanguage.en;

  /// [storedLang] (the `lang` preference) when it is supported; otherwise
  /// [deviceLanguageCode] (the device locale's language code, without the
  /// region) when it is supported; otherwise [fallback].
  static AppLanguage resolve({
    required String storedLang,
    required String deviceLanguageCode,
  }) =>
      LanguageCatalog.byCode(storedLang) ??
      LanguageCatalog.byCode(deviceLanguageCode) ??
      fallback;
}
