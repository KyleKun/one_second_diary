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

  // get string
  static String getString(String key, {String defValue = ''}) {
    if (_preferences == null) return defValue;
    return _preferences!.getString(key) ?? defValue;
  }

  // put string
  static Future<bool> putString(String key, String value) {
    return _preferences!.setString(key, value);
  }

  // get int
  static int? getInt(String key) {
    // ignore: avoid_returning_null
    if (_preferences == null) return null;
    return _preferences!.getInt(key);
  }

  // put int
  static Future<bool> putInt(String key, int value) {
    return _preferences!.setInt(key, value);
  }

  // get bool
  static bool? getBool(String key) {
    // ignore: avoid_returning_null
    if (_preferences == null) return null;
    return _preferences!.getBool(key);
  }

  // put bool
  static Future<bool> putBool(String key, bool value) {
    return _preferences!.setBool(key, value);
  }
}
