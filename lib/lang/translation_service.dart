import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'en.dart';
import 'es.dart';
import 'fr.dart';
import 'id.dart';
import 'pt.dart';
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
    LanguageModel('English', 'en'),
    LanguageModel('Português', 'pt'),
    LanguageModel('Español', 'es'),
    LanguageModel('Indonesia', 'id'),
    LanguageModel('中文', 'zh'),
    LanguageModel('Français', 'fr'),
  ];

  @override
  Map<String, Map<String, String>> get keys => {
        'en': en,
        'pt': pt,
        'es': es,
        'id': id,
        'zh': zh,
        'fr': fr,
      };
}
