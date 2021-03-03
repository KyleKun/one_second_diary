import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/lang/translation_service.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';
import 'package:one_second_diary/utils/utils.dart';

// TODO: fix
class LanguageController extends GetxController {
  @override
  void onInit() {
    selectedLanguage = _getLanguage();
    super.onInit();
  }

  var selectedLanguage = StorageUtil.getString('lang').obs;

  set changeLanguage(String lang) {
    Locale locale = new Locale(lang);
    Get.updateLocale(locale);
    StorageUtil.putString('lang', lang);
    selectedLanguage.value = lang;
    selectedLanguage.refresh();
  }

  RxString _getLanguage() {
    if (!(TranslationService.languages
        .contains(StorageUtil.getString('lang')))) {
      Utils().logInfo('Language Not Found!');
      StorageUtil.putString('lang', Get.deviceLocale.languageCode);
    }

    return StorageUtil.getString('lang').obs;
  }
}
