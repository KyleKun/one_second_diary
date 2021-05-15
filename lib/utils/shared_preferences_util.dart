import 'package:shared_preferences/shared_preferences.dart';

class StorageUtil {
  static StorageUtil? _storageUtil;
  static SharedPreferences? _preferences;

  static Future<StorageUtil> getInstance() async {
    if (_storageUtil == null) {
      var secureStorage = StorageUtil._();
      await secureStorage._init();
      _storageUtil = secureStorage;
    }
    return _storageUtil!;
  }

  StorageUtil._();
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
    if (_preferences == null) return null;
    return _preferences!.getInt(key);
  }

  // put int
  static Future<bool> putInt(String key, int value) {
    return _preferences!.setInt(key, value);
  }

  // get bool
  static bool? getBool(String key) {
    if (_preferences == null) return null;
    return _preferences!.getBool(key);
  }

  // put bool
  static Future<bool> putBool(String key, bool value) {
    return _preferences!.setBool(key, value);
  }
}
