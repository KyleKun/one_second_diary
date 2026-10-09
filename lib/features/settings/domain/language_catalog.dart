import 'package:one_second_diary/features/settings/domain/app_language.dart';

/// The languages the app supports, and the lookup from a stored code.
abstract final class LanguageCatalog {
  static final Map<String, AppLanguage> _byCode = AppLanguage.values
      .asNameMap();

  /// The supported language stored as [code], or null when the app has no
  /// translation for it.
  ///
  /// Older installs stored the device language on first launch even when it
  /// was not supported (`it`, `ja`, `fil`, …). Such a value is not a choice
  /// the user made, so callers treat null as "no language picked".
  static AppLanguage? byCode(String code) => _byCode[code];
}
