import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'constants.dart';
import 'shared_preferences_util.dart';

class Themes {
  static final light = ThemeData.light().copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.mainColor,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Magic'),
    primaryColor: AppColors.mainColor,
    colorScheme: ThemeData.light().colorScheme.copyWith(
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
    switchTheme: _switchTheme(isDark: false),
  );

  static final dark = ThemeData.dark().copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.mainColor,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Magic'),
    primaryColor: AppColors.mainColor,
    colorScheme: ThemeData.dark().colorScheme.copyWith(
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
    switchTheme: _switchTheme(isDark: true),
  );

  /// On: white thumb on a coral track. Off: grey thumb on an outlined,
  /// nearly transparent track — the previous theme painted the thumb coral
  /// in both states, so on and off were hard to tell apart.
  static SwitchThemeData _switchTheme({required bool isDark}) {
    bool on(Set<WidgetState> states) => states.contains(WidgetState.selected);
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => on(states)
            ? Colors.white
            : (isDark ? Colors.white70 : Colors.black45),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => on(states)
            ? AppColors.mainColor
            : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04)),
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => on(states)
            ? Colors.transparent
            : (isDark ? Colors.white30 : Colors.black26),
      ),
    );
  }
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
