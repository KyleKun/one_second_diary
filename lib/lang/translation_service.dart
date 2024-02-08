import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
  LanguageModel(
    this.language,
    this.symbol,
  );

  String language;
  String symbol;
}

class TranslationService extends Translations {
  static const fallbackLocale = Locale('en', 'US');

  static final List<LanguageModel> languages = [
    LanguageModel('Deutsch', 'de'),
    LanguageModel('English', 'en'),
    LanguageModel('Português', 'pt'),
    LanguageModel('Español', 'es'),
    LanguageModel('Indonesia', 'id'),
    LanguageModel('中文', 'zh'),
    LanguageModel('Français', 'fr'),
    LanguageModel('Русский', 'ru'),
    LanguageModel('Čeština', 'cs'),
    LanguageModel('Català', 'ca'),
    LanguageModel('Magyar', 'hu'),
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
        'hu': hu,
      };
}
