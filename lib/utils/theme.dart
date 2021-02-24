import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';

class Themes {
  static final light = ThemeData.light().copyWith(
    textTheme: ThemeData.light().textTheme.apply(
          fontFamily: 'Magic',
        ),
    primaryColor: Color(0xffff6366),
  );
  static final dark = ThemeData.dark().copyWith(
    textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'Magic',
        ),
  );
}

class ThemeService {
  final _key = 'isDarkMode';

  ThemeMode get theme => isDarkTheme() ? ThemeMode.dark : ThemeMode.light;

  bool isDarkTheme() => StorageUtil.getBool(_key) ?? false;

  _saveTheme(bool isDarkMode) => StorageUtil.putBool(_key, isDarkMode);

  void switchTheme() {
    Get.changeThemeMode(isDarkTheme() ? ThemeMode.light : ThemeMode.dark);
    _saveTheme(!isDarkTheme());
  }
}
