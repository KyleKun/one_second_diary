import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'be.dart';
import 'ca.dart';
import 'cs.dart';
import 'de.dart';
import 'en.dart';
import 'es.dart';
import 'fr.dart';
import 'hu.dart';
import 'id.dart';
import 'pt.dart';
import 'ru.dart';
import 'zh.dart';

class LanguageModel {
  LanguageModel(this.language, this.symbol, this.flagCountryCode);

  String language;
  String symbol;

  /// ISO 3166 country code of the flag shown next to [language] in the
  /// language picker.
  String flagCountryCode;
}

class TranslationService extends Translations {
  static const fallbackLocale = Locale('en', 'US');

  static final List<LanguageModel> languages = [
    LanguageModel('Deutsch', 'de', 'DE'),
    LanguageModel('English', 'en', 'US'),
    LanguageModel('Português', 'pt', 'BR'),
    LanguageModel('Español', 'es', 'ES'),
    LanguageModel('Indonesia', 'id', 'ID'),
    LanguageModel('中文', 'zh', 'CN'),
    LanguageModel('Français', 'fr', 'FR'),
    LanguageModel('Русский', 'ru', 'RU'),
    LanguageModel('Čeština', 'cs', 'CZ'),
    LanguageModel('Català', 'ca', 'AD'),
    LanguageModel('Беларуская', 'be', 'BY'),
    LanguageModel('Magyar', 'hu', 'HU'),
  ];

  @override
  Map<String, Map<String, String>> get keys => {
    'de': de,
    'en': en,
    'es': es,
    'id': id,
    'pt': pt,
    'zh': zh,
    'fr': fr,
    'ru': ru,
    'cs': cs,
    'ca': ca,
    'be': be,
    'hu': hu,
  };
}
