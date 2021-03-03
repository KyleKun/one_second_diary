import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/controllers/lang_controller.dart';
import 'package:one_second_diary/lang/translation_service.dart';

class LanguageChooser extends StatelessWidget {
  final String title = 'language'.tr;
  final LanguageController _languageController = Get.find<LanguageController>();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 15.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width * 0.045,
                ),
              ),
              DropdownButton<String>(
                isExpanded: false,
                isDense: false,
                value: _languageController.selectedLanguage.value,
                onChanged: (symbol) {
                  _languageController.changeLanguage = symbol!;
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
              ),
            ],
          ),
        ),
        Divider(),
      ],
    );
  }
}
