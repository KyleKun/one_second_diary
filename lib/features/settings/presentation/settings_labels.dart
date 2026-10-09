import 'package:one_second_diary/core/l10n/strings.dart';

/// Labels of the Settings pages that depend on more than one key.
abstract final class SettingsLabels {
  /// The Settings tab's "Preferences" row: the `preferences` key, except in
  /// a language that translated it with its word for "Settings" (de
  /// "Einstellungen", ru "Настройки"): there the row would repeat the tab's
  /// title, so it shows `settingsPreferencesDistinct`.
  static String get preferences => Strings.preferences == Strings.settings
      ? Strings.settingsPreferencesDistinct
      : Strings.preferences;
}
