import 'dart:io' as io;

import 'package:path_provider/path_provider.dart';

import 'shared_preferences_util.dart';
import 'utils.dart';

class StorageUtils {
  /// Create application folder in internal storage
  static Future<void> createFolder() async {
    try {
      final hasStoragePerms = await Utils.requestStoragePermissions();
      if (hasStoragePerms == false) {
        // Get.snackbar(
        //   'Oh no!',
        //   'Not all permissions were granted. Some app features may not work properly',
        // );
        Utils.logError('[StorageUtils] - ' +
            'Looks like some permissions were not granted');
      }

      io.Directory? appDirectory;
      io.Directory? moviesDirectory;

      // Checks if appPath is already stored
      String appPath = SharedPrefsUtil.getString('appPath');
      String moviesPath = SharedPrefsUtil.getString('moviesPath');

      // If it is not stored, dive into the device folders and store it properly
      if (appPath == '' || moviesPath == '') {
        String rootPath = '';
        appDirectory = await getExternalStorageDirectory();

        final List<String> folders = appDirectory!.path.split('/');
        for (int i = 1; i < folders.length; i++) {
          final String folder = folders[i];
          if (folder != 'Android') {
            rootPath += '/$folder';
          } else {
            break;
          }
        }

        // Storing appPath
        appPath = '$rootPath/OneSecondDiary/';
        SharedPrefsUtil.putString('appPath', appPath);
        // Storing moviesPath
        moviesPath = '$rootPath/OSD-Movies/';
        SharedPrefsUtil.putString('moviesPath', moviesPath);
      }

      // Checking if the folder really exists, if not, then create it
      appDirectory = io.Directory(appPath);
      moviesDirectory = io.Directory(moviesPath);

      // ignore: avoid_slow_async_io
      if (!await appDirectory.exists()) {
        await appDirectory.create(recursive: true);
        Utils.logInfo('[StorageUtils] - ' + 'Videos directory created');
      } else {
        Utils.logInfo('[StorageUtils] - ' + 'Videos directory already exists');
      }

      // ignore: avoid_slow_async_io
      if (!await moviesDirectory.exists()) {
        await moviesDirectory.create(recursive: true);
        Utils.logInfo('[StorageUtils] - ' + 'Movies directory created');
      } else {
        Utils.logInfo('[StorageUtils] - ' + 'Movies directory already exists');
      }
    } catch (e) {
      Utils.logError('[StorageUtils] - $e');
    }
  }

  // Create log file in internal storage
  static Future<void> createLogFile() async {
    try {
      final String appPath = SharedPrefsUtil.getString('appPath');
      final String logPath = '$appPath/Logs/';

      // Checking if the folder really exists, if not, then create it
      final io.Directory? logDirectory = io.Directory(logPath);

      // ignore: avoid_slow_async_io
      if (logDirectory != null && !await logDirectory.exists()) {
        await logDirectory.create(recursive: true);
      }

      final String logFileName = Utils.getTodaysLogFilename();

      // ignore: avoid_slow_async_io
      if (!await io.File('$logPath/$logFileName').exists()) {
        await io.File('$logPath/$logFileName').create(recursive: false);
        SharedPrefsUtil.putString('currentLogFile', logFileName);
      }

      // Delete old log files (7 days past today)
      final List<io.FileSystemEntity> files = logDirectory!.listSync();
      for (final io.FileSystemEntity file in files) {
        final String filename = file.path.split('/').last;
        final String date = filename.split('_').first;
        final DateTime fileDate = DateTime.parse(date);
        final DateTime today = DateTime.now();
        final int difference = today.difference(fileDate).inDays;

        if (difference > 7) {
          await io.File(file.path).delete();
        }
      }
    } catch (e) {
      Utils.logError('[StorageUtils] - $e');
    }
  }

  // Create specific profile folder in internal storage
  static Future<void> createSpecificProfileFolder(String profileName) async {
    try {
      final String appPath = SharedPrefsUtil.getString('appPath');
      final String profilePath = '$appPath/Profiles/$profileName/';

      // Checking if the folder really exists, if not, then create it
      final io.Directory? profileDirectory = io.Directory(profilePath);

      // ignore: avoid_slow_async_io
      if (profileDirectory != null && !await profileDirectory.exists()) {
        await profileDirectory.create(recursive: true);
      }
    } catch (e) {
      Utils.logError('[StorageUtils] - $e');
    }
  }

  // Delete specific profile folder in internal storage
  static Future<void> deleteSpecificProfileFolder(String profileName) async {
    try {
      final String appPath = SharedPrefsUtil.getString('appPath');
      final String profilePath = '$appPath/Profiles/$profileName';

      // Checking if the folder really exists, if not, then create it
      final io.Directory? profileDirectory = io.Directory(profilePath);

      if (profileDirectory!.existsSync()) {
        await profileDirectory.delete(recursive: true);
      }
    } catch (e) {
      Utils.logError('[StorageUtils] - $e');
    }
  }

  /// Rename file
  static void renameFile(String oldPath, String newPath) {
    if (checkFileExists(oldPath)) {
      try {
        io.File(oldPath).renameSync(newPath);
      } catch (e) {
        Utils.logError('[StorageUtils] - $e');
      }
    }
  }

  /// Used to check if daily video was already recorded
  static bool checkFileExists(String filePath) {
    return io.File(filePath).existsSync();
  }

  /// Delete old video if user is editing daily entry
  static void deleteFile(String filePath) {
    if (checkFileExists(filePath)) {
      io.File(filePath).deleteSync(recursive: true);
    }
  }
}
