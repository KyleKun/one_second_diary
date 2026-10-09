import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [SharedPreferences] in front of the mocked store, except that
/// the platform refuses every write to a key in [refused]: the plugin then
/// answers `false`, as it does when the disk is full.
///
/// Reads and the other writes go to the real instance, so a test sees the
/// state a device would be left in.
class RefusingSharedPreferences extends Fake implements SharedPreferences {
  RefusingSharedPreferences(this._real, {Set<String> refused = const {}})
    : refused = <String>{...refused};

  final SharedPreferences _real;

  /// Keys whose writes and removals the platform refuses.
  final Set<String> refused;

  bool _refuses(String key) => refused.contains(key);

  @override
  Object? get(String key) => _real.get(key);

  @override
  List<String>? getStringList(String key) => _real.getStringList(key);

  @override
  bool containsKey(String key) => _real.containsKey(key);

  @override
  Set<String> getKeys() => _real.getKeys();

  @override
  Future<bool> setBool(String key, bool value) async =>
      !_refuses(key) && await _real.setBool(key, value);

  @override
  Future<bool> setInt(String key, int value) async =>
      !_refuses(key) && await _real.setInt(key, value);

  @override
  Future<bool> setString(String key, String value) async =>
      !_refuses(key) && await _real.setString(key, value);

  @override
  Future<bool> setStringList(String key, List<String> value) async =>
      !_refuses(key) && await _real.setStringList(key, value);

  @override
  Future<bool> remove(String key) async =>
      !_refuses(key) && await _real.remove(key);
}

/// Installs [values] as the store and opens a [PrefsStore] whose
/// platform refuses writes as [RefusingSharedPreferences] does. Returns both,
/// so the test can script the refusals.
Future<(PrefsStore, RefusingSharedPreferences)> openRefusingPrefs(
  Map<String, Object> values, {
  Set<String> refused = const {},
}) async {
  SharedPreferences.setMockInitialValues(values);
  final RefusingSharedPreferences platform = RefusingSharedPreferences(
    await SharedPreferences.getInstance(),
    refused: refused,
  );
  return (PrefsStore(preferences: platform), platform);
}
