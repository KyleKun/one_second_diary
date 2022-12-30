import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'shared_preferences_util.dart';
import 'utils.dart';

class StorageUtils {
  /// Create application folder in internal storage
  static Future<void> createFolder() async {
    try {
      final hasStoragePerms = await Utils.requestStoragePermissions();
      debugPrint('Storage permissions enabled? $hasStoragePerms');

      if (hasStoragePerms == false) {
        // Get.snackbar(
        //   'Oh no!',
        //   'Not all permissions were granted. Some app features may not work properly',
        // );
        debugPrint('Looks like some permissions were not granted');
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
      debugPrint(e.toString());
      // Utils().logError('$e');
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
      debugPrint(e.toString());
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
      debugPrint(e.toString());
    }
  }

  /// Rename file
  static bool renameFile(String oldPath, String newPath) {
    try {
      io.File(oldPath).renameSync(newPath);
      return true;
    } catch (e) {
      debugPrint(e.toString());
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
