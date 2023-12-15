import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/utils/utils.dart';

import 'constants.dart';
import 'shared_preferences_util.dart';

class Vertical {


}

class VerticalService {
  final _key = 'isVerticalMode';

  // Dark Mode is true by default
  bool isVerticalMode() => SharedPrefsUtil.getBool(_key) ?? true;

  Future<bool> _saveVerticalMode(bool isDarkMode) =>
      SharedPrefsUtil.putBool(_key, isDarkMode);

  void switchVerticalMode() {
    Utils.logInfo("Switched vertical mode");
    //Get.changeThemeMode(isDarkTheme() ? ThemeMode.light : ThemeMode.dark);
    _saveVerticalMode(!isVerticalMode());
  }

  bool isProfileVertical(String profile) {
    switch (profile) {
      case "Sold":
        return true;
      case "Not Sold":
        return false;
      default:
        return false;
    }
  }
}
