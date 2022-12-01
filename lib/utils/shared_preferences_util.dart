import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsUtil {
  static SharedPrefsUtil? _storageUtil;
  static SharedPreferences? _preferences;

  static Future<SharedPrefsUtil> getInstance() async {
    if (_storageUtil == null) {
      final secureStorage = SharedPrefsUtil._();
      await secureStorage._init();
      _storageUtil = secureStorage;
    }
    return _storageUtil!;
  }

  SharedPrefsUtil._();

  Future _init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  static String getString(String key, {String defValue = ''}) {
    if (_preferences == null) return defValue;
    return _preferences!.getString(key) ?? defValue;
  }

  static Future<bool> putString(String key, String value) {
    return _preferences!.setString(key, value);
  }

  static int? getInt(String key) {
    if (_preferences == null) return null;
    return _preferences!.getInt(key);
  }

  static Future<bool> putInt(String key, int value) {
    return _preferences!.setInt(key, value);
  }

  static bool? getBool(String key) {
    if (_preferences == null) return null;
    return _preferences!.getBool(key);
  }

  static Future<bool> putBool(String key, bool value) {
    return _preferences!.setBool(key, value);
  }
}
