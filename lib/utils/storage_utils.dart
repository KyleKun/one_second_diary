// ignore_for_file: avoid_slow_async_io

import 'dart:io' as io;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../enums/video_orientation.dart';
import '../routes/app_pages.dart';
import 'app_paths.dart';
import 'constants.dart';
import 'custom_dialog.dart';
import 'media_gallery.dart';
import 'platform_utils.dart';
import 'shared_preferences_util.dart';
import 'utils.dart';

class StorageUtils {
  /// Resolves the app folders for the current platform and makes sure they
  /// exist. On Android it also migrates the pre v1.4 folder layout.
  static Future<void> createFolder() async {
    await AppPaths.init();

    // Logs folder has to exist before anything logs.
    await io.Directory('${AppPaths.internal}/Logs').create(recursive: true);
    SharedPrefsUtil.putString('currentLogFile', Utils.getNewLogFilename());
    Utils.logInfo('[App Started] - Log file created');
    Utils.logVerbose('[App Started] - Device date/time: ${DateTime.now()}');

    try {
      await _requestPermissions();
      await AppPaths.createDirectories();
      Utils.logInfo(
        '[StorageUtils] - Videos directory ready at ${AppPaths.videos}',
      );

      if (PlatformUtils.isAndroid) {
        await _migrateLegacyAndroidFolders();
      }
    } catch (e) {
      Utils.logError('[StorageUtils] - $e');
    }
  }

  static Future<void> _requestPermissions() async {
    if (!PlatformUtils.isAndroid) {
      // iOS grants the app its own container. Camera, microphone and photo
      // library prompts are raised by the plugins that need them, at the point
      // where they need them.
      return;
    }

    final AndroidDeviceInfo androidDeviceInfo =
        await DeviceInfoPlugin().androidInfo;
    final int sdkVersion = androidDeviceInfo.version.sdkInt;
    SharedPrefsUtil.putInt('sdkVersion', sdkVersion);

    final bool granted = await Utils.requestStoragePermissions(
      sdkVersion: sdkVersion,
    );
    if (!granted) {
      Utils.logError(
        '[StorageUtils] - Some storage permissions were not granted for sdk version $sdkVersion',
      );
    }
  }

  /// Moves videos recorded by older versions into the DCIM folder used since
  /// v1.4. Android only: no iOS build ever wrote to the old layout.
  static Future<void> _migrateLegacyAndroidFolders() async {
    final String internalDirectoryPath = AppPaths.internal;

    final io.Directory oldAppFolder = io.Directory(
      AppPaths.videos.replaceFirst(
        'DCIM/${AppPaths.folderName}/',
        '${AppPaths.folderName}/',
      ),
    );
    final io.Directory oldMoviesFolder = io.Directory(
      AppPaths.movies.replaceFirst(
        'DCIM/${AppPaths.folderName}/Movies/',
        'OSD-Movies/',
      ),
    );

    if (!await oldAppFolder.exists()) return;

    final io.Directory appDirectory = io.Directory(AppPaths.videos);
    final MediaGallery gallery = MediaGallery.instance;

    // Map all files inside old folders
    final List<io.FileSystemEntity> oldFolderFiles = await oldAppFolder
        .list(recursive: true)
        .toList();

    // Remove files that contain Logs in path
    oldFolderFiles.removeWhere((file) => file.path.contains('Logs'));

    // Avoid repeating it if the migration was already done and user forgot to delete old folder
    final List<io.FileSystemEntity> newFolderFiles = await appDirectory
        .list(recursive: true)
        .toList();
    List<String> alreadyMigratedFiles = [];
    if (newFolderFiles.length >= oldFolderFiles.length) {
      Utils.logInfo('[StorageUtils] - Old videos folder already migrated');
      return;
    } else if (newFolderFiles.isNotEmpty) {
      alreadyMigratedFiles = newFolderFiles
          .map((file) => file.path.split('/').last)
          .toList();
      debugPrint('Already migrated files: $alreadyMigratedFiles');
    }

    showDialog(
      barrierDismissible: false,
      context: Get.context!,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Icon(Icons.handyman, color: AppColors.green, size: 32.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('migrationInProgress'.tr, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const CircularProgressIndicator(color: AppColors.green),
              const SizedBox(height: 10),
              Text('doNotCloseTheApp'.tr, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );

    Utils.logInfo('[StorageUtils] - Migrating old videos to new folder');

    try {
      WakelockPlus.enable();
      debugPrint(oldFolderFiles.toString());

      // Control how many files were found to check if matches the copied number
      int validFiles = 0;
      int copiedFiles = 0;

      // Loop through all files and copy them to new folder
      await Future.forEach(oldFolderFiles, (file) async {
        if (file is! io.File ||
            !file.path.endsWith('.mp4') ||
            alreadyMigratedFiles.contains(file.path.split('/').last)) {
          return;
        }

        final List<String> pathSplitted = file.path.split('/');
        final bool isProfileVideo = file.path.contains('Profiles');
        final String folderName = isProfileVideo
            ? pathSplitted[pathSplitted.length - 2]
            : '';

        validFiles++;

        String tempFolderPath = internalDirectoryPath;
        if (isProfileVideo) {
          gallery.setAlbum('${AppPaths.folderName}/Profiles/$folderName');
          tempFolderPath = '$internalDirectoryPath/Profiles/$folderName';
          await io.Directory(tempFolderPath).create(recursive: true);
          await io.Directory(
            AppPaths.profileVideos(folderName),
          ).create(recursive: true);
          debugPrint(
            'Created profile folder ${AppPaths.profileVideos(folderName)}',
          );
          _registerProfile(folderName);
        } else {
          gallery.setAlbum(AppPaths.folderName);
        }

        final String copyFile = '$tempFolderPath/${pathSplitted.last}';
        await file.copy(copyFile);
        final bool saved = await gallery.save(
          tempFilePath: copyFile,
          destinationPath: isProfileVideo
              ? '${AppPaths.profileVideos(folderName)}${pathSplitted.last}'
              : '${AppPaths.videos}${pathSplitted.last}',
        );
        if (saved) {
          copiedFiles++;
          // Delete the original right away to avoid doubling storage usage.
          try {
            deleteFile(file.path);
          } catch (_) {
            // The migration can still succeed with the original left behind.
          }
        }
        debugPrint('[MediaGallery] Copied video $copyFile');
      });

      // If copying videos succeeded, then delete old folder and proceed to movies migration
      if (validFiles == copiedFiles) {
        if (await oldMoviesFolder.exists()) {
          final List<io.FileSystemEntity> oldMoviesFolderFiles =
              await oldMoviesFolder.list(recursive: true).toList();
          debugPrint(oldMoviesFolderFiles.toString());
          // Copy all movies files to new folder
          await Future.forEach(oldMoviesFolderFiles, (file) async {
            if (file is! io.File || !file.path.endsWith('.mp4')) return;

            gallery.setAlbum('${AppPaths.folderName}/Movies');
            final String tempFolderPath = '$internalDirectoryPath/Movies';
            await io.Directory(tempFolderPath).create(recursive: true);
            final String copyFile =
                '$tempFolderPath/${file.path.split('/').last}';
            await file.copy(copyFile);
            await gallery.save(
              tempFilePath: copyFile,
              destinationPath: '${AppPaths.movies}${file.path.split('/').last}',
            );
            try {
              deleteFile(file.path);
            } catch (_) {
              // Same as above, a leftover original is not fatal.
            }
            debugPrint('[MediaGallery] Copied movie $copyFile');
          });

          try {
            // Clean old movies folder
            await oldMoviesFolder.delete(recursive: true);
            Utils.logWarning(
              '[StorageUtils] - Migrated movies and deleted old folder',
            );
          } catch (_) {
            // Nothing else to do, the files are already in the new folder.
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
      WakelockPlus.disable();
      Utils.updateVideoCount();
      Get.offAllNamed(Routes.HOME);
    }
  }

  static void _registerProfile(String folderName) {
    List<String>? storedProfiles = SharedPrefsUtil.getStringList('profiles');
    if (storedProfiles == null || storedProfiles.isEmpty) {
      storedProfiles = ['Default'];
    }
    if (!storedProfiles.contains(folderName)) {
      storedProfiles.add(folderName);
      SharedPrefsUtil.putStringList('profiles', storedProfiles);
    }
  }

  // Delete log files older than a week
  static Future<void> cleanOldLogFiles() async {
    try {
      final String logsPath = '${AppPaths.internal}/Logs';

      final io.Directory logsDirectory = io.Directory(logsPath);
      if (!logsDirectory.existsSync()) return;

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
              '[StorageUtils] - Deleted old log file: ${file.path}',
            );
            await io.File(file.path).delete();
          }
        }
      }
    } catch (e) {
      Utils.logError('[StorageUtils] - $e');
    }
  }

  /// The SharedPreferences key [profileName]'s orientation is stored under.
  /// Uses the same "empty string means the Default profile" convention as
  /// [AppPaths.profileVideos] and `Utils.getCurrentProfile`.
  static String _orientationKey(String profileName) =>
      'orientation_$profileName';

  /// The orientation [profileName] was created with, defaulting to landscape
  /// for a profile that predates this field (see [VideoOrientation.parse]).
  static VideoOrientation getOrientation(String profileName) =>
      VideoOrientation.parse(
        SharedPrefsUtil.getString(_orientationKey(profileName)),
      );

  /// Persists [orientation] for [profileName].
  ///
  /// Call this only when a profile is first created — nothing else in the
  /// app calls it for an existing profile, because orientation is meant to
  /// stay fixed for a profile's whole lifetime. Every legitimate caller
  /// (profile creation, first-launch onboarding's Default profile — see
  /// [createDefaultProfile] — and "convert to the other orientation",
  /// which always creates a brand-new destination profile rather than
  /// mutating the source) only ever writes this once, to a profile name
  /// that has never had an orientation stored before.
  ///
  /// Throws a [StateError] instead of overwriting if [profileName] already
  /// has a stored orientation — that can only mean a bug elsewhere is
  /// calling this for a second time, and silently letting it through would
  /// mean a profile's clips get encoded to two different canvases without
  /// any error to explain why.
  static Future<void> setOrientation(
    String profileName,
    VideoOrientation orientation,
  ) {
    final String key = _orientationKey(profileName);
    if (SharedPrefsUtil.containsKey(key)) {
      final String message =
          '[StorageUtils] - Orientation already set for profile "$profileName" — refusing to overwrite.';
      Utils.logError(message);
      throw StateError(message);
    }
    return SharedPrefsUtil.putString(key, orientation.name);
  }

  /// Creates the Default profile — its 'profiles' entry plus explicit
  /// [orientation] — for a fresh install. Called once, from onboarding.
  ///
  /// ProfilesPage.validateProfileList() has its own fallback that also
  /// writes a bare `['Default']` list if 'profiles' is still missing by
  /// the time a user opens Profiles — but never calls [setOrientation]
  /// there, since that path has no explicit choice behind it and should
  /// grandfather to landscape.
  static Future<void> createDefaultProfile(VideoOrientation orientation) async {
    await SharedPrefsUtil.putStringList('profiles', ['Default']);
    await setOrientation('', orientation);
  }

  // Create specific profile folder
  static Future<void> createSpecificProfileFolder(String profileName) async {
    try {
      final io.Directory profileDirectory = io.Directory(
        AppPaths.profileVideos(profileName),
      );
      if (!await profileDirectory.exists()) {
        await profileDirectory.create(recursive: true);
      }
    } catch (e) {
      Utils.logError('[StorageUtils] - $e');
    }
  }

  // Delete specific profile folder
  static Future<void> deleteSpecificProfileFolder(String profileName) async {
    try {
      final io.Directory profileDirectory = io.Directory(
        AppPaths.profileVideos(profileName),
      );
      if (profileDirectory.existsSync()) {
        await profileDirectory.delete(recursive: true);
      }
    } catch (e) {
      Utils.logError('[StorageUtils] - $e');
    }

    // Outside the try above on purpose: this must still run even if deleting
    // the folder itself failed, otherwise the name is stuck with a stale
    // orientation if it's ever reused, and setOrientation would wrongly
    // refuse it as a duplicate.
    await SharedPrefsUtil.removeKey(_orientationKey(profileName));
  }

  static void renameFile(String oldPath, String newPath) {
    if (checkFileExists(oldPath)) {
      try {
        io.File(oldPath).renameSync(newPath);
      } catch (e) {
        Utils.logError('[StorageUtils] - $e');
      }
    }
  }

  static bool checkFileExists(String filePath) {
    return io.File(filePath).existsSync();
  }

  static void deleteFile(String filePath) {
    if (checkFileExists(filePath)) {
      io.File(filePath).deleteSync(recursive: true);
    }
  }

  /// Deletes a video, going through the platform media index when there is one.
  /// Prefer this over [deleteFile] for anything the user can see in a gallery.
  static Future<bool> deleteVideo(String filePath) {
    return MediaGallery.instance.delete(filePath);
  }
}
