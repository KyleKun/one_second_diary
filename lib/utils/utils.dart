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

    // Adding a leading zero on Days and Months <= 9
    final String day = now.day <= 9 ? "0${now.day}" : "${now.day}";
    final String month = now.month <= 9 ? "0${now.month}" : "${now.month}";
    final String year = "${now.year}";

    // Brazilian pattern
    if (isBr) {
      return "$day-$month-$year";
    } else {
      return "$year-$month-$day";
    }
  }

  static List<DateTime> orderDates(List<DateTime> dates) {
    dates.sort((a, b) {
      return a.compareTo(b);
    });
    return dates;
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
    // var time = Stopwatch()..start();
    if (io.File(filePath).existsSync()) {
      // time.stop();
      // Utils().logInfo(time.elapsed);
      return true;
    } else {
      // time.stop();
      // Utils().logInfo(time.elapsed);
      return false;
    }
  }

  static void deleteFile(String filePath) {
    io.File(filePath).deleteSync(recursive: true);
  }

  static Future<String> writeTxt(List<String> files) async {
    final io.Directory directory = await getApplicationDocumentsDirectory();
    final String txtPath = '${directory.path}/videos.txt';
    final String appPath = StorageUtil.getString('appPath');

    // Delete old txt files
    if (checkFileExists(txtPath)) deleteFile(txtPath);

    final io.File file = io.File(txtPath);

    for (int i = 0; i < files.length; i++) {
      // file model accepted by ffmpeg to be written
      String ffString = "file '$appPath${files[i]}'\r\n";

      // Not adding a new line at the end
      if (i == files.length - 1) ffString = "file '$appPath${files[i]}'";

      // Appending it to the txt
      await file.writeAsString(ffString, mode: io.FileMode.append);
    }

    // final _data = await file.readAsString();
    // Utils().logWarning(_data);

    return txtPath;
  }

  static List<String> getAllVideosFromStorage() {
    final directory = io.Directory(StorageUtil.getString('appPath'));

    List<io.FileSystemEntity> _files;

    _files = directory.listSync(recursive: true, followLinks: false);
    List<String> allFiles = [];

    // Getting video names
    for (int i = 0; i < _files.length; i++) {
      String temp = _files[i].toString().split('.').first;
      temp = temp.split('/').last;
      allFiles.add(temp);
    }

    // Converting to Date in order to sort
    List<DateTime> allDates = [];
    for (int i = 0; i < allFiles.length; i++) {
      allDates.add(DateTime.parse(allFiles[i]));
    }

    List<DateTime> orderedDates = Utils.orderDates(allDates);

    // Converting back to string
    List<String> allVideos = [];
    for (int i = 0; i < orderedDates.length; i++) {
      // Adding a leading zero on Days and Months <= 9
      String day = orderedDates[i].day <= 9
          ? "0${orderedDates[i].day}"
          : "${orderedDates[i].day}";
      String month = orderedDates[i].month <= 9
          ? "0${orderedDates[i].month}"
          : "${orderedDates[i].month}";
      String year = "${orderedDates[i].year}";

      allVideos.add('$year-$month-$day.mp4');
    }

    return allVideos;
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
