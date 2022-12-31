import 'dart:io' as io;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/video_count_controller.dart';
import '../enums/export_date_range.dart';
import 'date_format_utils.dart';
import 'shared_preferences_util.dart';
import 'storage_utils.dart';

final logger = Logger(
  printer: PrettyPrinter(printTime: true),
  level: Level.verbose,
);

class Utils {
  static void launchURL(String url) async {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  static void logInfo(info) {
    logger.i(info);
    final String file = SharedPrefsUtil.getString('currentLogFile');
    final String now = DateTime.now().toString();
    final String line = '[INFO] $now: ${info.toString()}';
    appendLineToFile(file, line);
  }

  static void logWarning(warning) {
    logger.w(warning);
    final String file = SharedPrefsUtil.getString('currentLogFile');
    final String now = DateTime.now().toString();
    final String line = '[WARNING] $now: ${warning.toString()}';
    appendLineToFile(file, line);
  }

  static void logError(error) {
    logger.e(error);
    final String file = SharedPrefsUtil.getString('currentLogFile');
    final String now = DateTime.now().toString();
    final String stacktrace =
        Trace.from(StackTrace.current).terse.frames.first.toString();
    final line =
        '[ERROR] $now: ${error.toString()}' + '\nStacktrace: $stacktrace';
    appendLineToFile(file, line);
  }

  /// Used to request Android permissions
  static Future<bool> requestPermission(Permission permission) async {
    if (await permission.isGranted) {
      logInfo(
          '[Utils.requestPermission()] - Permission ${permission.toString()} was already granted');
      return true;
    } else {
      final result = await permission.request();
      if (result == PermissionStatus.granted) {
        logInfo(
            '[Utils.requestPermission()] - Permission ${permission.toString()} granted!');
        return true;
      } else {
        logInfo(
            '[Utils.requestPermission()] - Permission ${permission.toString()} denied!');
        return false;
      }
    }
  }

  /// Used to request storage-specific Android permissions due to Android 13 breaking changes
  static Future<bool> requestStoragePermissions() async {
    final androidDeviceInfo = await DeviceInfoPlugin().androidInfo;
    late final Map<Permission, PermissionStatus> permissionStatuses;

    if (androidDeviceInfo.version.sdkInt <= 32) {
      // For android 12 and below devices
      permissionStatuses = await [
        Permission.storage,
        Permission.manageExternalStorage
      ].request();
    } else {
      permissionStatuses = await [
        Permission.videos,
        Permission.photos,
        Permission.audio,
        Permission.manageExternalStorage
      ].request();
    }

    bool allAccepted = true;
    permissionStatuses.forEach((permission, status) {
      if (status != PermissionStatus.granted) {
        allAccepted = false;
      }
      print(permissionStatuses);
    });

    if (allAccepted) {
      return true;
    } else {
      return false;
    }
  }

  // Example 2022-01-01_12-30-45.txt
  static String getTodaysLogFilename() {
    return '${DateTime.now().toString().split('.')[0].replaceAll(':', '-').replaceAll(' ', '_')}.txt';
  }

  // Add a new line to txt log file
  static Future<void> appendLineToFile(String fileName, String line) async {
    if (fileName.isEmpty) return;
    final String appPath = SharedPrefsUtil.getString('appPath');

    // Open the file for appending
    final file = io.File('$appPath/Logs/$fileName');
    final sink = file.openWrite(mode: io.FileMode.append);

    // Write the line to the file
    sink.write('$line\n');

    // Close the file
    await sink.close();
  }

  /// Write txt used by ffmpeg to concatenate videos when generating movie
  static Future<String> writeTxt(List<String> files) async {
    final io.Directory directory = await getApplicationDocumentsDirectory();
    final String txtPath = '${directory.path}/videos.txt';
    logInfo('[Utils.writeTxt()] - Writing txt file to $txtPath');

    // Get current profile
    final currentProfileName = getCurrentProfile();

    // Default directory
    String videosFolderPath = SharedPrefsUtil.getString('appPath');

    // If a profile is selected, use that directory
    if (currentProfileName != '') {
      videosFolderPath = '${videosFolderPath}Profiles/$currentProfileName/';
    }

    // Delete old txt files
    StorageUtils.deleteFile(txtPath);

    final io.File file = io.File(txtPath);

    for (int i = 0; i < files.length; i++) {
      final String filePath = videosFolderPath + files[i];

      // Add file and a new line at the end
      String ffString = "file '$filePath'\r\n";

      // Avoid adding a new line at the end of the file
      if (i == files.length - 1) ffString = "file '$filePath'";

      // Appending it to the txt
      await file.writeAsString(ffString, mode: io.FileMode.append);
    }

    logInfo('[Utils.writeTxt()] - Text file written successfully!');

    return txtPath;
  }

  /// Write dummy m4a file used by ffmpeg to add audio to the a video
  // static Future<String> writeM4a() async {
  //   final io.Directory directory = await getApplicationDocumentsDirectory();
  //   final String m4aPath = '${directory.path}/dummy.m4a';

  //   // Check if file exists and end it here if so
  //   // if (StorageUtils.checkFileExists(m4aPath)) return m4aPath;

  //   // ffmpeg command to create m4a file with 48000Hz sample rate

  //   try {
  //     await executeFFmpeg(
  //       '-f lavfi -i anullsrc=cl=mono -t 1 $m4aPath -y',
  //     );
  //     debugPrint('Dummy m4a file created');
  //   } catch (e) {
  //     print(e);
  //   }

  //   return m4aPath;
  // }

  /// Write srt file used by ffmpeg to add subtitles to the movie
  static Future<String> writeSrt(String text, int videoDuration) async {
    final io.Directory directory = await getApplicationDocumentsDirectory();
    final String srtPath = '${directory.path}/subtitles.srt';
    logInfo('[Utils.writeSrt()] - Writing srt file to $srtPath');

    // Delete old srt files
    StorageUtils.deleteFile(srtPath);

    final io.File file = io.File(srtPath);

    // Add linebreaks if a line is > 45 chars
    text = '$text\n';
    final List<String> lines = text.split('\n');
    text = '';
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].length > 45) {
        final List<String> words = lines[i].split(' ');
        String temp = '';
        for (int j = 0; j < words.length; j++) {
          if (temp.length + words[j].length > 45) {
            text += '$temp\n';
            temp = '';
          }
          temp += '${words[j]} ';
        }
        text += '$temp\n';
      } else {
        text += '${lines[i]}\n';
      }
    }

    final String totalSeconds = videoDuration == 10 ? '10' : '0$videoDuration';
    logInfo('[Utils.writeSrt()] - Subtitles total duration $videoDuration');
    final String subtitles =
        '1\r\n00:00:00,000 --> 00:00:$totalSeconds,000\r\n$text\r\n';

    // Writing file
    await file.writeAsString(subtitles, mode: io.FileMode.write);

    logInfo('[Utils.writeSrt()] - Subtitles file written successfully!');

    return srtPath;
  }

  /// Get current profile name, empty string if Default
  static String getCurrentProfile() {
    // Get current profile
    String currentProfileName = '';

    final selectedProfileIndex =
        SharedPrefsUtil.getInt('selectedProfileIndex') ?? 0;
    if (selectedProfileIndex != 0) {
      final allProfiles = SharedPrefsUtil.getStringList('profiles');
      if (allProfiles != null) {
        currentProfileName = allProfiles[selectedProfileIndex];
      }
    }

    final profileLog =
        currentProfileName == '' ? 'Default' : currentProfileName;
    logInfo('[Utils.getCurrentProfile()] - Selected profile: $profileLog');

    return currentProfileName;
  }

  /// Get all video files inside OneSecondDiary folder
  static List<String> getAllVideos({bool fullPath = false}) {
    // Get current profile
    final currentProfileName = getCurrentProfile();

    // Default directory
    io.Directory directory = io.Directory(SharedPrefsUtil.getString('appPath'));

    // If a profile is selected, use that directory
    if (currentProfileName != '') {
      directory = io.Directory(
          '${SharedPrefsUtil.getString('appPath')}Profiles/$currentProfileName/');
    }

    final List<io.FileSystemEntity> files =
        directory.listSync(recursive: true, followLinks: false);
    final List<String> mp4Files = [];

    // Getting video names
    logInfo(
        '[Utils.getAllVideos()] - Getting all videos inside ${directory.path}');
    for (int i = 0; i < files.length; i++) {
      final String filePath = files[i].path;
      if (filePath.contains('.mp4') && !filePath.contains('temp')) {
        // Make sure we are not counting in videos from other profiles if default is selected
        if (currentProfileName.isEmpty && filePath.contains('Profiles')) {
          continue;
        }
        if (fullPath) {
          mp4Files.add(filePath);
        } else {
          final String videoName = filePath.split('.mp4').first.split('/').last;
          mp4Files.add(videoName);
        }
      }
    }

    // Sorting files
    mp4Files.sort((a, b) => a.compareTo(b));
    logInfo('[Utils.getAllVideos()] - Asked for full path: $fullPath');
    logInfo('[Utils.getAllVideos()] - Sorted videos: $mp4Files');

    return mp4Files;
  }

  // Update the counter based on the amount of mp4 files inside the app folder
  static void updateVideoCount() {
    final allFiles = getAllVideos();
    final VideoCountController _videoCountController = Get.find();

    final int numberOfVideos = allFiles.length;

    final snackBar = SnackBar(
      margin: const EdgeInsets.all(10.0),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black54,
      duration: const Duration(seconds: 3),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(25),
        ),
      ),
      content: Text(
        (numberOfVideos != 1)
            ? '$numberOfVideos ${'foundVideos'.tr}'
            : '$numberOfVideos ${'foundVideo'.tr}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    );

    ScaffoldMessenger.of(Get.context!).showSnackBar(snackBar);

    // Setting videoCount number
    _videoCountController.setVideoCount(numberOfVideos);
  }

  /// Get a filtered list of mp4 files names ordered by date to be written on a txt file
  /// To get all videos, use `ExportDateRange.allTime`
  static List<String> getSelectedVideosFromStorage(
      ExportDateRange exportDateRange) {
    final now = DateTime.now();
    final List<String> allVideos = [];

    /// We use the properties of `now` instead of just calling `DateTime.now()` because we want to offset from the current date at a little past midnight
    /// Not doing this causes incorrect results in some scenarios
    final today = DateTime(now.year, now.month, now.day, 0, 1);

    try {
      final allFiles = getAllVideos();

      // Converting to Date in order to sort
      final List<DateTime> allDates = [];
      for (int i = 0; i < allFiles.length; i++) {
        allDates.add(DateTime.parse(allFiles[i]));
      }

      switch (exportDateRange) {
        case ExportDateRange.last7Days:
          final last7Days = today.subtract(const Duration(days: 7));
          for (int i = 0; i < allDates.length; i++) {
            allDates.removeWhere((e) => e.isBefore(last7Days));
          }
          break;
        case ExportDateRange.last30Days:
          final last30Days = today.subtract(const Duration(days: 30));
          for (int i = 0; i < allDates.length; i++) {
            allDates.removeWhere((e) => e.isBefore(last30Days));
          }
          break;
        case ExportDateRange.last60Days:
          final last60Days = today.subtract(const Duration(days: 60));
          for (int i = 0; i < allDates.length; i++) {
            allDates.removeWhere((e) => e.isBefore(last60Days));
          }
          break;
        case ExportDateRange.last90Days:
          final last90Days = today.subtract(const Duration(days: 90));
          for (int i = 0; i < allDates.length; i++) {
            allDates.removeWhere((e) => e.isBefore(last90Days));
          }
          break;
        case ExportDateRange.thisMonth:
          for (int i = 0; i < allDates.length; i++) {
            // Retains all the dates from the beginning of the month until the current date
            allDates.retainWhere(
              (e) =>
                  e.compareTo(DateTime(now.year, now.month)) >= 0 &&
                  e.compareTo(now) <= 0,
            );
          }
          break;
        case ExportDateRange.thisYear:
          for (int i = 0; i < allDates.length; i++) {
            // Retains all the dates from the start of the year until the current date within the year
            allDates.retainWhere(
              (e) =>
                  e.compareTo(DateTime(now.year)) >= 0 && e.compareTo(now) <= 0,
            );
          }
          break;
        case ExportDateRange.lastYear:
          for (int i = 0; i < allDates.length; i++) {
            // Retains all the dates from the start to the end of the previous year
            allDates.retainWhere(
              (e) =>
                  e.compareTo(DateTime(now.year - 1)) >= 0 &&
                  e.compareTo(DateTime(now.year)) < 0,
            );
          }
          break;
        case ExportDateRange.custom:
        case ExportDateRange.allTime:
        default:
        // Nothing else needs to be done here
      }

      final List<DateTime> orderedDates = DateFormatUtils.orderDates(allDates);

      // Converting back to string
      for (int i = 0; i < orderedDates.length; i++) {
        // Adding a leading zero on Days and Months <= 9
        final String day = orderedDates[i].day <= 9
            ? '0${orderedDates[i].day}'
            : '${orderedDates[i].day}';
        final String month = orderedDates[i].month <= 9
            ? '0${orderedDates[i].month}'
            : '${orderedDates[i].month}';
        final String year = '${orderedDates[i].year}';

        allVideos.add('$year-$month-$day.mp4');
      }
    } catch (e) {}
    return allVideos;
  }

  static Future<String> copyFontToStorage() async {
    final io.Directory directory = await getApplicationDocumentsDirectory();
    final String fontPath = '${directory.path}/magic.ttf';
    try {
      if (StorageUtils.checkFileExists(fontPath)) {
        logInfo('Text font for ffmpeg already exists, not copying it.');
      } else {
        final ByteData data =
            await rootBundle.load('assets/fonts/YuseiMagic-Regular.ttf');
        final List<int> bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await io.File(fontPath).writeAsBytes(bytes);
        logInfo('Text font for ffmpeg copied to $fontPath');
      }
    } catch (e) {
      logError(e);
    }

    return fontPath;
  }
}
