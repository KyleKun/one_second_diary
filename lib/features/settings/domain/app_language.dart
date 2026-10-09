/// One of the languages the app is translated into.
///
/// The value name is the two-letter code stored in the `lang` preference and
/// handed to the localisation and date APIs. Values are declared in the
/// order the language sheet shows them: Latin-script names alphabetically
/// (with "Bahasa Indonesia" under I), then Cyrillic, then Han. The order is
/// fixed here instead of computed with a collator, which would sort
/// differently per locale.
enum AppLanguage {
  ca(nativeName: 'Català', flagCountryCode: 'AD'),
  cs(nativeName: 'Čeština', flagCountryCode: 'CZ'),
  de(nativeName: 'Deutsch', flagCountryCode: 'DE'),
  en(nativeName: 'English', flagCountryCode: 'US'),
  es(nativeName: 'Español', flagCountryCode: 'ES'),
  fr(nativeName: 'Français', flagCountryCode: 'FR'),
  id(nativeName: 'Bahasa Indonesia', flagCountryCode: 'ID'),
  hu(nativeName: 'Magyar', flagCountryCode: 'HU'),
  pt(nativeName: 'Português', flagCountryCode: 'BR'),
  be(nativeName: 'Беларуская', flagCountryCode: 'BY'),
  ru(nativeName: 'Русский', flagCountryCode: 'RU'),
  zh(nativeName: '中文', flagCountryCode: 'CN');

  const AppLanguage({required this.nativeName, required this.flagCountryCode});

  /// The language's name in itself (its endonym). Never translated.
  final String nativeName;

  /// ISO 3166 country code of the flag shown next to [nativeName]: Catalan
  /// uses Andorra, English the US, Portuguese Brazil (the translation is
  /// Brazilian) and Chinese China (Simplified).
  final String flagCountryCode;

  /// The two-letter code stored in `lang`.
  String get code => name;
}
