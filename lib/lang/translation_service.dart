import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'de.dart';
import 'en.dart';
import 'es.dart';
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
    LanguageModel('Deutsch', 'de'),
    LanguageModel('English', 'en'),
    LanguageModel('Português', 'pt'),
    LanguageModel('Español', 'es'),
    LanguageModel('Indonesia', 'id'),
    LanguageModel('中文', 'zh')
  ];

  @override
  Map<String, Map<String, String>> get keys => {
        'de': de,
        'en': en,
        'es': es,
        'id': id,
        'pt': pt,
        'zh': zh,
      };
}
