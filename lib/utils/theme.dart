import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'constants.dart';
import 'shared_preferences_util.dart';

class Themes {
  static final light = ThemeData.light().copyWith(
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.mainColor),
    textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Magic'),
    primaryColor: AppColors.mainColor,
    colorScheme: ColorScheme.fromSwatch().copyWith(
      secondary: AppColors.mainColor,
    ),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: AppColors.light,
      hourMinuteTextColor: AppColors.dark,
      dialTextColor: AppColors.dark,
      dialHandColor: AppColors.mainColor,
      hourMinuteColor: Colors.white38,
      dayPeriodTextColor: AppColors.mainColor,
      entryModeIconColor: AppColors.dark,
    ),
    listTileTheme: const ListTileThemeData(
      tileColor: AppColors.light,
      iconColor: AppColors.dark,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.green,
      selectionColor: AppColors.green,
      selectionHandleColor: AppColors.green,
    ),
  );

  static final dark = ThemeData.dark().copyWith(
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.dark),
    textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'Magic',
        ),
    primaryColor: AppColors.mainColor,
    colorScheme: ColorScheme.fromSwatch().copyWith(
      secondary: AppColors.mainColor,
    ),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: AppColors.dark,
      hourMinuteTextColor: AppColors.light,
      hourMinuteColor: Colors.black38,
      dayPeriodTextColor: AppColors.light,
    ),
    listTileTheme: const ListTileThemeData(
      tileColor: AppColors.dark,
      iconColor: AppColors.light,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.green,
      selectionColor: AppColors.green,
      selectionHandleColor: AppColors.green,
    ),
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
