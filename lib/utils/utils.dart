import 'package:flutter_ffmpeg/log_level.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import 'dart:io' as io;
import 'shared_preferences_util.dart';

class Utils {
  final logger = Logger(
    printer: PrettyPrinter(),
    level: Level.verbose,
  );

  void logInfo(dynamic info) {
    logger.i(info);
  }

  void logWarning(dynamic warning) {
    logger.w(warning);
  }

  void logError(dynamic warning) {
    logger.e(warning);
  }

  static String getToday({bool isBr = false}) {
    var now = new DateTime.now();
    // Brazilian pattern
    if (isBr) {
      return "${now.day}-${now.month}-${now.year}";
    } else {
      return "${now.year}-${now.month}-${now.day}";
    }
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
      Utils().logInfo('Permission was already granted');
      return true;
    } else {
      var result = await permission.request();
      if (result == PermissionStatus.granted) {
        Utils().logInfo('Permission granted!');
        return true;
      } else {
        Utils().logWarning('Permission denied!');
        return false;
      }
    }
  }

  static bool checkFileExists(String filePath) {
    if (io.File(filePath).existsSync()) {
      return true;
    } else {
      return false;
    }
  }

  static void deleteFile(String filePath) {
    io.File(filePath).deleteSync(recursive: true);
  }

  static void createFolder() async {
    try {
      await requestPermission(Permission.storage);
      io.Directory directory;

      // Checks if appPath is already stored
      String appPath = StorageUtil.getString('appPath') ?? '';

      // If it is not stored, dive into the device folders and store it properly
      if (appPath == '') {
        directory = await getExternalStorageDirectory();

        List<String> folders = directory.path.split('/');
        for (int i = 1; i < folders.length; i++) {
          String folder = folders[i];
          if (folder != "Android") {
            appPath += "/" + folder;
          } else {
            break;
          }
        }

        // Storing appPath
        appPath = appPath + "/OneSecondDiary/";
        StorageUtil.putString('appPath', appPath);
      }

      Utils().logInfo('APP PATH: $appPath');

      // Checking if the folder really exists, if not, then create it
      directory = io.Directory(appPath);

      if (!await directory.exists()) {
        await directory.create(recursive: true);
        Utils().logInfo("Directory created");
        Utils().logInfo('Final Directory path: ' + directory.path);
      } else {
        Utils().logInfo("Directory already exists");
      }
    } catch (e) {
      Utils().logError('$e');
    }
  }
}
