import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/controllers/lang_controller.dart';
import 'package:one_second_diary/lang/translation_service.dart';

class LanguageChooser extends StatelessWidget {
  final LanguageController _languageController = Get.find<LanguageController>();

  @override
  Widget build(BuildContext context) {
    print(_languageController.selectedLanguage.value);
    return DropdownButton<String>(
      isExpanded: true,
      isDense: true,
      value: _languageController.selectedLanguage.value,
      onChanged: (symbol) {
        _languageController.changeLanguage = symbol;
      },
      items: TranslationService.languages.map(
        (LanguageModel _language) {
          print(_language.symbol);
          return DropdownMenuItem<String>(
            child: new Text(_language.language),
            value: _language.symbol,
          );
        },
      ).toList(),
    );
  }
}
