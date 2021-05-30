import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'constants.dart';
import 'shared_preferences_util.dart';

class Themes {
  static final light = ThemeData.light().copyWith(
    textTheme: ThemeData.light().textTheme.apply(
          fontFamily: 'Magic',
        ),
    primaryColor: AppColors.mainColor,
    accentColor: AppColors.mainColor,
  );
  static final dark = ThemeData.dark().copyWith(
    textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'Magic',
        ),
    accentColor: AppColors.mainColor,
  );
}

class ThemeService {
  final _key = 'isDarkMode';

  ThemeMode get theme => isDarkTheme() ? ThemeMode.dark : ThemeMode.light;

  // Dark Mode is true by default
  bool isDarkTheme() => SharedPrefsUtil.getBool(_key) ?? true;

  Future<bool> _saveTheme(bool isDarkMode) =>
      SharedPrefsUtil.putBool(_key, isDarkMode);

  void switchTheme() {
    Get.changeThemeMode(isDarkTheme() ? ThemeMode.light : ThemeMode.dark);
    _saveTheme(!isDarkTheme());
  }
}
