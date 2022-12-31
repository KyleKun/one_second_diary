import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/shared_preferences_util.dart';
import '../utils/utils.dart';

class LanguageController extends GetxController {
  @override
  void onInit() {
    selectedLanguage = _getLanguage();
    super.onInit();
  }

  var selectedLanguage = SharedPrefsUtil.getString('lang').obs;

  set changeLanguage(String lang) {
    final Locale locale = Locale(lang);
    Get.updateLocale(locale);
    SharedPrefsUtil.putString('lang', lang);
    selectedLanguage.value = lang;
    selectedLanguage.refresh();
  }

  RxString _getLanguage() {
    if (SharedPrefsUtil.getString('lang').length != 2) {
      Utils.logInfo('Language Not Found!');
      SharedPrefsUtil.putString('lang', Get.deviceLocale!.languageCode);
      Get.updateLocale(Get.deviceLocale!);
    } else {
      final Locale locale = Locale(SharedPrefsUtil.getString('lang'));
      Get.updateLocale(locale);
    }
    Utils.logInfo('Selected language: ${SharedPrefsUtil.getString('lang')}');
    return SharedPrefsUtil.getString('lang').obs;
  }
}
