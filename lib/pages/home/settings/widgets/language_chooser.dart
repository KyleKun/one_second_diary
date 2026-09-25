import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../controllers/lang_controller.dart';
import '../../../../lang/translation_service.dart';
import 'language_picker_sheet.dart';

/// Settings row showing the current language (with its flag); tapping it
/// opens [LanguagePickerSheet].
class LanguageChooser extends StatelessWidget {
  const LanguageChooser({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final LanguageController languageController = Get.find();

    return Column(
      children: [
        InkWell(
          onTap: () => LanguagePickerSheet.show(context),
          child: Ink(
            padding: const EdgeInsets.symmetric(
              horizontal: 15.0,
              vertical: 10.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'language'.tr,
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width * 0.045,
                    ),
                  ),
                ),
                Obx(() {
                  final LanguageModel? language =
                      LanguagePickerSheet.languageFor(
                        languageController.selectedLanguage.value,
                      );
                  if (language == null) return const Icon(Icons.translate);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LanguageFlag(
                        countryCode: language.flagCountryCode,
                        width: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        language.language,
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.04,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}
