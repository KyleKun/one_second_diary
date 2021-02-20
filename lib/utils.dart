import 'package:permission_handler/permission_handler.dart';

class Utils {
  static String getToday() {
    var now = new DateTime.now();
    return "${now.year}-${now.month}-${now.day}";
  }

  static Future<bool> requestPermission(Permission permission) async {
    if (await permission.isGranted) {
      return true;
    } else {
      var result = await permission.request();
      if (result == PermissionStatus.granted) {
        return true;
      } else {
        return false;
      }
    }
  }
}
