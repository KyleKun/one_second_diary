import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';
// import 'package:one_second_diary/utils/utils.dart';

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
    if (StorageUtil.getString('lang').length != 2) {
      // Utils().logInfo('Language Not Found!');
      StorageUtil.putString('lang', Get.deviceLocale!.languageCode);
      Get.updateLocale(Get.deviceLocale!);
    } else {
      Locale locale = new Locale(StorageUtil.getString('lang'));
      Get.updateLocale(locale);
    }
    // Utils().logInfo('Selected language: ${StorageUtil.getString('lang')}');
    return StorageUtil.getString('lang').obs;
  }
}
