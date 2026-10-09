/// The plural forms a translation of a plural key needs, by language: every
/// CLDR category easy_localization picks for a whole number in that
/// language, plus `other`.
///
/// A missing form doesn't show an error: easy_localization shows the English
/// form for that category (one of `one` / `other`) or the language's own
/// `other`, which has the wrong grammar in ru, be and cs ("3 клипов" for
/// "3 клипа"). `other` covers fractions and is the last fallback of every
/// category. `osd_localization_test.dart` checks this table against
/// easy_localization's rules.
const Map<String, Set<String>> requiredPluralForms = {
  'be': {'one', 'few', 'many', 'other'},
  'ca': {'one', 'other'},
  'cs': {'one', 'few', 'other'},
  'de': {'one', 'other'},
  'en': {'one', 'other'},
  'es': {'one', 'other'},
  'fr': {'one', 'other'},
  'hu': {'one', 'other'},
  'id': {'other'},
  'pt': {'one', 'other'},
  'ru': {'one', 'few', 'many', 'other'},
  'zh': {'other'},
};
