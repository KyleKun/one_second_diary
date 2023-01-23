// ignore_for_file: avoid_slow_async_io

import 'dart:io' as io;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../routes/app_pages.dart';
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

    // Create logs folder
    await io.Directory('${internalDirectoryPath.path}/Logs').create();
    // Set current log file path
    SharedPrefsUtil.putString('currentLogFile', Utils.getNewLogFilename());
    Utils.logInfo('[App Started] - ' + 'Log file created');

    // Get android sdk info
    final androidDeviceInfo = await DeviceInfoPlugin().androidInfo;
    final sdkVersion = androidDeviceInfo.version.sdkInt;
    SharedPrefsUtil.putInt('sdkVersion', sdkVersion);

    final mediaStorePlugin = MediaStore();

    try {
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

      // Migrate old videos to new folder inside DCIM if needed
      final io.Directory oldAppFolder = io.Directory(
          SharedPrefsUtil.getString('appPath')
              .replaceFirst('DCIM/OneSecondDiary/', 'OneSecondDiary/'));
      final io.Directory oldMoviesFolder = io.Directory(
          SharedPrefsUtil.getString('moviesPath')
              .replaceFirst('DCIM/OneSecondDiary/Movies/', 'OSD-Movies/'));

      if (await oldAppFolder.exists()) {
        // Map all files inside old folders
        final oldFolderFiles =
            await oldAppFolder.list(recursive: true).toList();

        // Avoid repeating it if the migration was already done and user forgot to delete old folder
        final newFolderFiles =
            await appDirectory.list(recursive: true).toList();
        if (newFolderFiles.length >= oldFolderFiles.length) {
          Utils.logInfo(
            '[StorageUtils] - Old videos folder already migrated',
          );
          return;
        }

        showDialog(
          barrierDismissible: false,
          context: Get.context!,
          builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: const Icon(
                Icons.handyman,
                color: AppColors.green,
                size: 32.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'migrationInProgress'.tr,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const CircularProgressIndicator(
                    color: AppColors.green,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'doNotCloseTheApp'.tr,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );

        Utils.logInfo(
          '[StorageUtils] - Migrating old videos to new folder',
        );

        try {
          debugPrint(oldFolderFiles.toString());

          // Control how many files were found to check if matches the copied number
          int validFiles = 0;
          int copiedFiles = 0;

          // Loop through all files and copy them to new folder
          await Future.forEach(oldFolderFiles, (file) async {
            // Handle profile folders for beta users
            if (file is io.File &&
                file.path.contains('Profiles') &&
                file.path.endsWith('.mp4')) {
              validFiles++;
              final pathSplitted = file.path.split('/');

              // Create the profile folder
              final folderName = pathSplitted[pathSplitted.length - 2];
              MediaStore.appFolder = 'OneSecondDiary/Profiles/$folderName';
              final tempFolderPath =
                  '${internalDirectoryPath.path}/Profiles/$folderName/';
              await io.Directory(tempFolderPath).create(recursive: true);
              final newFolderPath =
                  '${SharedPrefsUtil.getString('appPath')}Profiles/$folderName/';
              await io.Directory(newFolderPath).create(recursive: true);
              debugPrint('Created profile folder $newFolderPath');

              // Update shared prefs
              // Get profiles from persistence
              List<String>? storedProfiles =
                  SharedPrefsUtil.getStringList('profiles');
              if (storedProfiles == null || storedProfiles.isEmpty) {
                // Add the default profile to storage
                storedProfiles = ['Default'];
              }

              if (storedProfiles.contains(folderName) == false) {
                storedProfiles.add(folderName);
                SharedPrefsUtil.putStringList('profiles', storedProfiles);
              }

              // Copy the file to the profile folder
              final copyFile = tempFolderPath + pathSplitted.last;
              await file.copy(copyFile);
              await mediaStorePlugin
                  .saveFile(
                tempFilePath: copyFile,
                dirType: DirType.video,
                dirName: DirName.dcim,
              )
                  .then((_) {
                copiedFiles++;
                deleteFile(copyFile);

                // We try to delete the original file right away after copy to avoid increased storage usage
                try {
                  deleteFile(file.path);
                } catch (e) {
                  // Do nothing
                }
              });
              debugPrint('[MediaStore] Copied profile video $copyFile');
            }

            // Copy only mp4 files to root path (default profile)
            else if (file is io.File && file.path.endsWith('.mp4')) {
              MediaStore.appFolder = 'OneSecondDiary';
              validFiles++;
              final copyFile =
                  '${internalDirectoryPath.path}/${file.path.split('/').last}';
              await file.copy(copyFile);
              await mediaStorePlugin
                  .saveFile(
                tempFilePath: copyFile,
                dirType: DirType.video,
                dirName: DirName.dcim,
              )
                  .then((_) {
                copiedFiles++;
                deleteFile(copyFile);

                // We try to delete the original file right away after copy to avoid increased storage usage
                try {
                  deleteFile(file.path);
                } catch (e) {
                  // Do nothing
                }
              });
              debugPrint('[MediaStore] Copied video $copyFile');
            }
          });

          // If copying videos succeeded, then delete old folder and proceed to movies migration
          if (validFiles == copiedFiles) {
            if (await oldMoviesFolder.exists()) {
              final oldMoviesFolderFiles =
                  await oldMoviesFolder.list(recursive: true).toList();
              debugPrint(oldMoviesFolderFiles.toString());
              // Copy all movies files to new folder
              await Future.forEach(oldMoviesFolderFiles, (file) async {
                if (file is io.File && file.path.endsWith('.mp4')) {
                  MediaStore.appFolder = 'OneSecondDiary/Movies';
                  final tempFolderPath =
                      '${internalDirectoryPath.path}/Movies/';
                  await io.Directory(tempFolderPath).create(recursive: true);
                  final copyFile =
                      '$tempFolderPath${file.path.split('/').last}';
                  await file.copy(copyFile);
                  await mediaStorePlugin
                      .saveFile(
                    tempFilePath: copyFile,
                    dirType: DirType.video,
                    dirName: DirName.dcim,
                  )
                      .then((_) {
                    deleteFile(copyFile);

                    // We try to delete the original file right away after copy to avoid increased storage usage
                    try {
                      deleteFile(file.path);
                    } catch (e) {
                      // Do nothing
                    }
                  });
                  debugPrint('[MediaStore] Copied movie $copyFile');
                }
              });

              try {
                // Clean old movies folder
                await oldMoviesFolder.delete(recursive: true);
                Utils.logWarning(
                  '[StorageUtils] - Migrated movies and deleted old folder',
                );
              } catch (e) {
                // Do nothing
              }
            }

            // Clean old videos folder
            try {
              await oldAppFolder.delete(recursive: true);
              Utils.logWarning(
                '[StorageUtils] - Migrated videos and deleted old folder',
              );
            } catch (e) {
              Utils.logError(
                '[StorageUtils] - Tried to delete old videos folders but failed',
              );
              Get.back();
              await showDialog(
                barrierDismissible: false,
                context: Get.context!,
                builder: (context) => CustomDialog(
                  isDoubleAction: false,
                  title: '😬',
                  content: 'migrationFolderDeletionError'.tr,
                  actionText: 'Ok',
                  actionColor: Colors.orange,
                  action: () => Get.back(),
                ),
              );
            }

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
          } else {
            Utils.logError(
              '[StorageUtils] - Tried to migrate videos but not all files were copied',
            );
            Get.back();
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
        } catch (e) {
          Utils.logError(
            '[StorageUtils] - Could not migrate old videos: ${e.toString()}',
          );
          Get.back();
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
        } finally {
          Utils.updateVideoCount();
          Get.offAllNamed(Routes.HOME);
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
          '${SharedPrefsUtil.getString('internalDirectoryPath')}/Logs';

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
