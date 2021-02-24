import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

class Utils {
  final logger = Logger(
    printer: PrettyPrinter(),
  );

  void logInfo(String info) {
    logger.i(info);
  }

  void logWarning(String warning) {
    logger.w(warning);
  }

  static String getToday() {
    var now = new DateTime.now();
    return "${now.year}-${now.month}-${now.day}";
  }

  static void launchUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
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
