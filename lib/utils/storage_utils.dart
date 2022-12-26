import 'dart:io' as io;

import 'package:path_provider/path_provider.dart';

import 'shared_preferences_util.dart';
import 'utils.dart';

class StorageUtils {
  /// Create application folder in internal storage
  static Future<void> createFolder() async {
    try {
      final hasStoragePerms = await Utils.requestStoragePermissions();
      print('Storage perms enabled? $hasStoragePerms');

      if (hasStoragePerms == false) {
        // Get.snackbar(
        //   'Oh no!',
        //   'Not all permissions were granted. Some app features may not work properly',
        // );
        print('Looks like some permissions were not granted');
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
        // Utils().logInfo("Directory created");
        // Utils().logInfo('Final Directory path: ' + directory.path);
      } else {
        // Utils().logInfo("Directory already exists");
      }

      // ignore: avoid_slow_async_io
      if (!await moviesDirectory.exists()) {
        await moviesDirectory.create(recursive: true);
        // Utils().logInfo("Directory created");
        // Utils().logInfo('Final Directory path: ' + directory.path);
      } else {
        // Utils().logInfo("Directory already exists");
      }
    } catch (e) {
      print(e);
      // Utils().logError('$e');
    }
  }

  /// Rename file
  static bool renameFile(String oldPath, String newPath) {
    try {
      io.File(oldPath).renameSync(newPath);
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  /// Used to check if daily video was already recorded
  static bool checkFileExists(String filePath) {
    return io.File(filePath).existsSync();
  }

  /// Delete old video if user is editing daily entry
  static void deleteFile(String filePath) {
    io.File(filePath).deleteSync(recursive: true);
  }
}
