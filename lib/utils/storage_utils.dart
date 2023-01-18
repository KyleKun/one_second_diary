// ignore_for_file: avoid_slow_async_io

import 'dart:io' as io;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'constants.dart';
import 'custom_dialog.dart';
import 'shared_preferences_util.dart';
import 'utils.dart';

class StorageUtils {
  /// Create application folder in internal storage
  static Future<void> createFolder() async {
    // Set internal appDirectoryPath
    final io.Directory internalDirectoryPath =
        await getApplicationDocumentsDirectory();
    SharedPrefsUtil.putString(
      'internalDirectoryPath',
      internalDirectoryPath.path,
    );

    // Set current log file path
    SharedPrefsUtil.putString('currentLogFile', Utils.getNewLogFilename());

    // Get android sdk info
    final androidDeviceInfo = await DeviceInfoPlugin().androidInfo;
    final sdkVersion = androidDeviceInfo.version.sdkInt;

    // We have set this otherwise it throws AppFolderNotSetException
    MediaStore.appFolder = 'OneSecondDiary';

    try {
      Utils.logInfo('[App Started] - ' + 'Log file created');

      final hasStoragePerms = await Utils.requestStoragePermissions(
        sdkVersion: sdkVersion,
      );
      if (hasStoragePerms == false) {
        Utils.logError('[StorageUtils] - ' +
            'Some storage permissions were not granted for sdk version $sdkVersion');
      }

      io.Directory? appDirectory;
      io.Directory? moviesDirectory;

      // Checks if appPath is already stored
      String appPath = SharedPrefsUtil.getString('appPath');
      String moviesPath = SharedPrefsUtil.getString('moviesPath');

      // If it is not stored, dive into the device folders and store it properly
      if (!appPath.contains('DCIM')) {
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
        appPath = '$rootPath/DCIM/OneSecondDiary/';
        SharedPrefsUtil.putString('appPath', appPath);
        // Storing moviesPath
        moviesPath = '$rootPath/DCIM/OneSecondDiary/Movies/';
        SharedPrefsUtil.putString('moviesPath', moviesPath);
      }

      // Checking if the folder really exists, if not, then create it
      appDirectory = io.Directory(appPath);
      moviesDirectory = io.Directory(moviesPath);

      if (!await appDirectory.exists()) {
        await appDirectory.create(recursive: true);
        Utils.logInfo('[StorageUtils] - ' + 'Videos directory created');
      } else {
        Utils.logInfo('[StorageUtils] - ' + 'Videos directory already exists');
      }

      if (!await moviesDirectory.exists()) {
        await moviesDirectory.create(recursive: true);
        Utils.logInfo('[StorageUtils] - ' + 'Movies directory created');
      } else {
        Utils.logInfo('[StorageUtils] - ' + 'Movies directory already exists');
      }

      // TODO(KyleKun): synchronize async calls or something else since it seems the folder can be deleted before finishing copying files
      // TODO(KyleKun): Elsewhere, migrate save methods to use MediaStore instead of file system
      // Migrate old videos to new folder inside DCIM if needed
      final io.Directory oldAppFolder = io.Directory(
          SharedPrefsUtil.getString('appPath')
              .replaceFirst('DCIM/OneSecondDiary/', 'OneSecondDiary/'));
      final io.Directory oldMoviesFolder = io.Directory(
          SharedPrefsUtil.getString('moviesPath')
              .replaceFirst('DCIM/OneSecondDiary/Movies/', 'OSD-Movies/'));

      if (await oldAppFolder.exists()) {
        showDialog(
          barrierDismissible: false,
          context: Get.context!,
          builder: (context) => AlertDialog(
            title: const Icon(Icons.handyman),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: Text('migrationInProgress'.tr),
          ),
        );

        Utils.logInfo(
          '[StorageUtils] - Migrating old videos to new folder',
        );

        try {
          await oldAppFolder.list(recursive: false).forEach((element) async {
            if (element is io.File && element.path.endsWith('.mp4')) {
              final _file = SharedPrefsUtil.getString('appPath') +
                  element.path.split('/').last;
              await element.copy(_file);
            }
          });

          // Copy movies folder if it exists
          if (await oldMoviesFolder.exists()) {
            await oldMoviesFolder
                .list(recursive: false)
                .forEach((element) async {
              if (element is io.File && element.path.endsWith('.mp4')) {
                final _file = SharedPrefsUtil.getString('moviesPath') +
                    element.path.split('/').last;
                await element.copy(_file);
              }
            });
            await oldMoviesFolder.delete(recursive: true);
            Utils.logWarning(
              '[StorageUtils] - Migrated movies and deleted old folder',
            );
          }

          await oldAppFolder.delete(recursive: true);
          Utils.logWarning(
            '[StorageUtils] - Migrated all videos and deleted old folder',
          );
          Get.back();
          await showDialog(
            barrierDismissible: false,
            context: Get.context!,
            builder: (context) => CustomDialog(
              isDoubleAction: false,
              title: 'success'.tr,
              content: 'migrationSuccess'.tr,
              actionText: 'Ok',
              actionColor: AppColors.green,
              action: () => Get.back(),
            ),
          );
        } catch (e) {
          Utils.logError(
            '[StorageUtils] - Could not migrate old videos: ${e.toString()}',
          );
          Get.back();
          // Just in case copying files failed
          await showDialog(
            barrierDismissible: false,
            context: Get.context!,
            builder: (context) => CustomDialog(
              isDoubleAction: false,
              title: 'error'.tr,
              content: 'migrationError'.tr,
              actionText: 'Ok',
              actionColor: Colors.red,
              action: () => Get.back(),
            ),
          );
        }
      }
    } catch (e) {
      Utils.logError('[StorageUtils] - $e');
    }
  }

  // Create log file in internal storage
  static Future<void> cleanOldLogFiles() async {
    try {
      final String logsPath =
          SharedPrefsUtil.getString('internalDirectoryPath');

      final io.Directory logsDirectory = io.Directory(logsPath);

      // Delete old log files (7 days past today)
      final List<io.FileSystemEntity> files = logsDirectory.listSync();
      for (final io.FileSystemEntity file in files) {
        if (file.path.endsWith('.txt') && !file.path.contains('videos')) {
          final String filename = file.path.split('/').last;
          final String date = filename.split('_').first;
          final DateTime fileDate = DateTime.parse(date);
          final DateTime today = DateTime.now();
          final int difference = today.difference(fileDate).inDays;

          if (difference > 7) {
            Utils.logInfo(
                '[StorageUtils] - ' + 'Deleted old log file: ${file.path}');
            await io.File(file.path).delete();
          }
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
