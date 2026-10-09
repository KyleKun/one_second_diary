import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/storage/pref_key.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Typed access to the app's preferences.
///
/// Wraps the plugin's LEGACY `SharedPreferences.getInstance()` API on
/// purpose: that is where every existing install keeps its settings
/// (`FlutterSharedPreferences.xml` with the `flutter.` prefix on Android,
/// `NSUserDefaults` on iOS). Never swap in `SharedPreferencesAsync` or
/// `SharedPreferencesWithCache`: on Android they default to a separate
/// DataStore file, and every existing user would look like a fresh install.
///
/// Keys are declared once in `PrefKeys` with their exact stored name, type
/// and reader default.
class PrefsStore {
  PrefsStore({required this._preferences});

  /// Opens the store. Call once in bootstrap, before the first frame.
  static Future<PrefsStore> open() async =>
      PrefsStore(preferences: await SharedPreferences.getInstance());

  final SharedPreferences _preferences;

  /// The stored value of [key], or its default when absent.
  ///
  /// A value stored with another type (a corrupt or foreign entry) also reads
  /// as the default, instead of throwing the `TypeError` the plugin's typed
  /// getters would.
  T read<T>(PrefKey<T> key) {
    final Object? stored = _preferences.get(key.name);
    final Object? value = switch (key.type) {
      PrefType.boolean when stored is bool => stored,
      PrefType.integer when stored is int => stored,
      PrefType.string when stored is String => stored,
      // The platform channel decodes lists as List<Object?>.
      PrefType.stringList when stored is List => _preferences.getStringList(
        key.name,
      ),
      _ => null,
    };
    return value == null ? key.defaultValue : value as T;
  }

  /// Whether [key] is stored at all (as opposed to reading its default).
  bool contains(PrefKey<Object?> key) => _preferences.containsKey(key.name);

  /// Stores [value] under [key]; `null` removes the key. Completes once the
  /// platform has persisted it; throws a [StorageException] when the
  /// platform refuses the write.
  ///
  /// Dart infers `T` from both arguments, so a mismatched value compiles; it
  /// is rejected here with an [ArgumentError] naming the key.
  Future<void> write<T>(PrefKey<T> key, T value) async {
    if (value == null) return remove(key);
    final bool saved = switch ((key.type, value)) {
      (PrefType.boolean, final bool v) => await _preferences.setBool(
        key.name,
        v,
      ),
      (PrefType.integer, final int v) => await _preferences.setInt(key.name, v),
      (PrefType.string, final String v) => await _preferences.setString(
        key.name,
        v,
      ),
      (PrefType.stringList, final List<String> v) =>
        await _preferences.setStringList(key.name, v),
      _ => throw ArgumentError.value(
        value,
        'value',
        'is not a ${key.type.name} for preference "${key.name}"',
      ),
    };
    _throwUnless(saved, 'write', key);
  }

  /// Deletes [key], so it reads as its default again.
  Future<void> remove(PrefKey<Object?> key) async {
    _throwUnless(await _preferences.remove(key.name), 'remove', key);
  }

  static void _throwUnless(bool done, String action, PrefKey<Object?> key) {
    if (!done) {
      throw StorageException('The platform refused to $action "${key.name}"');
    }
  }
}
