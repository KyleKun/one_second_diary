import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nothing stored: a first launch.
const Map<String, Object> freshInstallPrefs = <String, Object>{};

/// Preference values as older installs store them, for
/// `SharedPreferences.setMockInitialValues` (keys without the `flutter.`
/// prefix; the mock adds it).
///
/// The defaults describe a user who finished onboarding with a landscape
/// Default profile. Pass null to leave a key out. [orientations] maps a
/// profile key (`''` = Default) to its stored `orientation_<key>` value.
/// [extra] adds any other key by name, e.g.
/// `{PrefKeys.isDarkMode.name: false}`.
Map<String, Object> legacyPrefs({
  bool? showIntro = false,
  List<String>? profiles = const <String>['Default'],
  int? selectedProfileIndex = 0,
  Map<String, String> orientations = const <String, String>{'': 'landscape'},
  int? videoCount = 0,
  int? movieCount = 1,
  Map<String, Object> extra = const <String, Object>{},
}) => <String, Object>{
  'showIntro': ?showIntro,
  'profiles': ?profiles,
  'selectedProfileIndex': ?selectedProfileIndex,
  for (final MapEntry<String, String> entry in orientations.entries)
    'orientation_${entry.key}': entry.value,
  'videoCount': ?videoCount,
  'movieCount': ?movieCount,
  ...extra,
};

/// Installs [values] as the preference store (resetting the plugin's
/// singleton) and opens a [PrefsStore] on it.
Future<PrefsStore> openLegacyPrefs(Map<String, Object> values) {
  SharedPreferences.setMockInitialValues(values);
  return PrefsStore.open();
}
