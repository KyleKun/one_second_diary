import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:synchronized/synchronized.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/video_count_controller.dart';
import '../enums/export_date_range.dart';
import '../enums/video_orientation.dart';
import 'app_paths.dart';
import 'date_format_utils.dart';
import 'shared_preferences_util.dart';
import 'storage_utils.dart';

final logger = Logger(
  printer: PrettyPrinter(dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart),
  level: Level.trace,
);

final lock = Lock();

class Utils {
  /// Whether the user has opted into verbose logging from Preferences.
  /// Gates extra diagnostic logging (e.g. movie creation's date filtering)
  /// that's too noisy to always write to the log file.
  static bool get isVerboseLoggingEnabled =>
      SharedPrefsUtil.getBool('verboseLogging') ?? false;

  static void launchURL(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  static Future<void> logInfo(info) async {
    logger.i(info);
    final String now = DateTime.now().toString();
    final String line = '[INFO] $now: ${info.toString()}';
    await lock.synchronized(() => appendLineToLogFile(line));
  }

  /// Same as [logInfo], but only written when the user has enabled verbose
  /// logging from Preferences. Use this for extra diagnostic detail that's
  /// too noisy to always keep in the log file.
  static Future<void> logVerbose(info) async {
    if (!isVerboseLoggingEnabled) return;
    logger.i(info);
    final String now = DateTime.now().toString();
    final String line = '[VERBOSE] $now: ${info.toString()}';
    await lock.synchronized(() => appendLineToLogFile(line));
  }

  static Future<void> logWarning(warning) async {
    logger.w(warning);
    final String now = DateTime.now().toString();
    final String line = '[WARNING] $now: ${warning.toString()}';
    await lock.synchronized(() => appendLineToLogFile(line));
  }

  static Future<void> logError(error) async {
    logger.e(error);
    final String now = DateTime.now().toString();
    final String stacktrace = Trace.from(
      StackTrace.current,
    ).terse.frames.first.toString();
    final line =
        '[ERROR] $now: ${error.toString()}' + '\nStacktrace: $stacktrace';
    await lock.synchronized(() => appendLineToLogFile(line));
  }

  // Add a new line to txt log file
  static Future<void> appendLineToLogFile(String line) async {
    // Anything can log, including code that runs before the paths are resolved
    // or after the folder was removed. Losing a log line is never worth an
    // unhandled asynchronous error.
    if (!AppPaths.isReady) return;
    final String fileName = SharedPrefsUtil.getString('currentLogFile');
    if (fileName.isEmpty) return;
    try {
      final file = io.File('${AppPaths.internal}/Logs/$fileName');
      await file.writeAsString('$line\n', mode: io.FileMode.writeOnlyAppend);
    } catch (_) {
      // Nothing sensible to do here, writing the failure would recurse.
    }
  }

  // Example 2022-01-01_12-30-45.txt
  static String getNewLogFilename() {
    return '${DateTime.now().toString().split('.')[0].replaceAll(':', '-').replaceAll(' ', '_')}.txt';
  }

  /// Used to request Android permissions
  static Future<bool> requestPermission(Permission permission) async {
    if (await permission.isGranted) {
      logInfo(
        '[Utils.requestPermission()] - Permission ${permission.toString()} was already granted',
      );
      return true;
    } else {
      final result = await permission.request();
      if (result == PermissionStatus.granted) {
        logInfo(
          '[Utils.requestPermission()] - Permission ${permission.toString()} granted!',
        );
        return true;
      } else {
        logInfo(
          '[Utils.requestPermission()] - Permission ${permission.toString()} denied!',
        );
        return false;
      }
    }
  }

  /// Used to request storage-specific Android permissions due to Android 13 breaking changes
  static Future<bool> requestStoragePermissions({
    required int sdkVersion,
  }) async {
    late final Map<Permission, PermissionStatus> permissionStatuses;

    if (sdkVersion <= 32) {
      // For android 12 and below devices
      permissionStatuses = await [Permission.storage].request();
    } else {
      permissionStatuses = await [Permission.videos].request();
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

  /// Write txt used to avoid drawtext not supporting special chars for location text
  static Future<String> writeLocationTxt(String? location) async {
    final String txtPath = '${AppPaths.internal}/location.txt';

    logInfo(
      '[Utils.writeLocationTxt()] - Writing location txt file to $txtPath',
    );

    // Delete old txt files
    StorageUtils.deleteFile(txtPath);

    final io.File file = io.File(txtPath);

    // Line to be added to the txt
    final String ffString = location?.isNotEmpty == true ? '$location\r' : '';

    // Appending it to the txt
    await file.writeAsString(ffString, mode: io.FileMode.append);
    debugPrint('$location added to txt file');

    logInfo('[Utils.writeLocationTxt()] - Text file written successfully!');

    return txtPath;
  }

  /// Write txt used by ffmpeg to concatenate videos when generating movie
  static Future<String> writeTxt(List<String> files) async {
    final String txtPath = '${AppPaths.internal}/videos.txt';

    logInfo('[Utils.writeTxt()] - Writing txt file to $txtPath');

    final String videosFolderPath = AppPaths.profileVideos(getCurrentProfile());

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
      debugPrint('$filePath added to txt file');
    }

    logInfo('[Utils.writeTxt()] - Text file written successfully!');

    return txtPath;
  }

  /// Write srt file used by ffmpeg to add subtitles to the movie
  static Future<String> writeSrt(
    String text,
    int videoStartMilliseconds,
    int videoEndMilliseconds,
  ) async {
    final String srtPath = '${AppPaths.internal}/subtitles.srt';
    logInfo('[Utils.writeSrt()] - Writing srt file to $srtPath');

    // Delete old srt files
    StorageUtils.deleteFile(srtPath);

    final io.File file = io.File(srtPath);

    // Add linebreaks if a line is > 45 chars
    String subsContent = '$text\n';
    final List<String> lines = subsContent.split('\n');
    subsContent = '';
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].length > 45) {
        final List<String> words = lines[i].split(' ');
        String temp = '';
        for (int j = 0; j < words.length; j++) {
          if (temp.length + words[j].length > 45) {
            subsContent += '$temp\n';
            temp = '';
          }
          temp += '${words[j]} ';
        }
        subsContent += '$temp\n';
      } else {
        subsContent += '${lines[i]}\n';
      }
    }

    // Calculate subtitles duration and format it
    final String secondsAndMillisecondsStart = millisecondsToSRTFormat(
      videoStartMilliseconds,
      videoStartMilliseconds,
    );
    logInfo(
      '[Utils.writeSrt()] - Subtitles start duration $secondsAndMillisecondsStart',
    );

    final String secondsAndMillisecondsEnd = millisecondsToSRTFormat(
      videoEndMilliseconds,
      videoStartMilliseconds,
    );
    logInfo(
      '[Utils.writeSrt()] - Subtitles end duration $secondsAndMillisecondsEnd',
    );

    final String subtitles =
        '1\r\n$secondsAndMillisecondsStart --> $secondsAndMillisecondsEnd\r\n$subsContent\r\n';

    // Writing file
    await file.writeAsString(subtitles, mode: io.FileMode.write);
    logInfo('[Utils.writeSrt()] - Subtitles file written successfully!');

    return srtPath;
  }

  /// Convert milliseconds to time format used in srt files
  static String millisecondsToSRTFormat(
    int milliseconds,
    int videoStartMilliseconds,
  ) {
    final int adjustedMilliseconds = milliseconds - videoStartMilliseconds;
    final Duration duration = Duration(milliseconds: adjustedMilliseconds);
    final int seconds = duration.inSeconds % 60;
    final int minutes = duration.inMinutes % 60;
    final int hours = duration.inHours % 24;
    milliseconds = adjustedMilliseconds % 1000;
    final String secondsString = seconds.toString().padLeft(2, '0');
    final String minutesString = minutes.toString().padLeft(2, '0');
    final String hoursString = hours.toString().padLeft(2, '0');
    final String millisecondsString = milliseconds.toString().padLeft(3, '0');
    return '$hoursString:$minutesString:$secondsString,$millisecondsString';
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

    final profileLog = currentProfileName == ''
        ? 'Default'
        : currentProfileName;
    logInfo('[Utils.getCurrentProfile()] - Selected profile: $profileLog');

    return currentProfileName;
  }

  /// The active profile's orientation — the canvas its saved clips and
  /// compiled movie should target. Resolves "current profile" the same way
  /// [getCurrentProfile] does, so this always reads the same profile that
  /// videos are actually being saved into.
  static VideoOrientation getCurrentOrientation() =>
      StorageUtils.getOrientation(getCurrentProfile());

  /// Get all video files inside DCIM/OneSecondDiary/Movies folder
  static List<String> getAllMovies({bool fullPath = false}) {
    logInfo('[Utils.getAllMovies()] - Asked for full path: $fullPath');

    final io.Directory directory = io.Directory(AppPaths.movies);
    if (!directory.existsSync()) return [];

    final List<io.FileSystemEntity> files = directory.listSync(
      recursive: true,
      followLinks: false,
    );
    final List<String> mp4Files = [];

    // Get all mp4 files
    for (int i = 0; i < files.length; i++) {
      if (files[i].path.endsWith('.mp4')) {
        if (fullPath) {
          mp4Files.add(files[i].path);
        } else {
          mp4Files.add(files[i].path.split('/').last);
        }
      }
    }

    logInfo('[Utils.getAllMovies()] - Found ${mp4Files.length} movies');

    return mp4Files.reversed.toList();
  }

  /// Get all video files inside DCIM/OneSecondDiary folder
  static List<String> getAllVideos({bool fullPath = false}) {
    logInfo('[Utils.getAllVideos()] - Asked for full path: $fullPath');
    // Get current profile
    final currentProfileName = getCurrentProfile();

    final io.Directory directory = io.Directory(
      AppPaths.profileVideos(currentProfileName),
    );
    if (!directory.existsSync()) return [];

    final List<io.FileSystemEntity> files = directory.listSync(
      recursive: true,
      followLinks: false,
    );
    final List<String> mp4Files = [];

    // Getting video names
    logInfo(
      '[Utils.getAllVideos()] - Getting all videos inside ${directory.path}',
    );
    for (int i = 0; i < files.length; i++) {
      // Full path of the file
      final String filePath = files[i].path;

      // Grab only file name without extension and directory path
      final String fileNameCheck = filePath.split('/').last.split('.').first;

      // Check if file is a video and if it is in the right format
      final bool isProperVideoFile =
          RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fileNameCheck) &&
          filePath.endsWith('.mp4') &&
          !filePath.contains('Movies');

      if (isProperVideoFile) {
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

    logInfo('[Utils.getAllVideos()] - ${mp4Files.length} videos found.');

    // Sorting files
    mp4Files.sort((a, b) => a.compareTo(b));

    return mp4Files;
  }

  // Update the counter based on the amount of mp4 files inside the app folder
  static void updateVideoCount({bool showSnackBar = true}) {
    final VideoCountController _videoCountController = Get.find();
    final allFiles = getAllVideos();
    final int numberOfVideos = allFiles.length;

    if (showSnackBar) {
      final snackBar = SnackBar(
        margin: const EdgeInsets.all(10.0),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black54,
        duration: const Duration(seconds: 3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25)),
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
    }

    // Setting videoCount number
    _videoCountController.setVideoCount(numberOfVideos);
    logInfo(
      '[Utils.updateVideoCount()] - Video count updated to $numberOfVideos',
    );
  }

  /// Get a filtered list of mp4 files names ordered by date to be written on a txt file
  /// To get all videos, use `ExportDateRange.allTime`
  static List<String> getSelectedVideosFromStorage(
    ExportDateRange exportDateRange,
  ) {
    final now = DateTime.now();
    final List<String> allVideos = [];

    /// We use the properties of `now` instead of just calling `DateTime.now()` because we want to offset from the current date at a little past midnight
    /// Not doing this causes incorrect results in some scenarios
    final today = DateTime(now.year, now.month, now.day, 0, 1);

    logVerbose(
      '[Utils.getSelectedVideosFromStorage()] - Requested range: $exportDateRange. '
      "Device's current date/time (DateTime.now()): $now. Filtering reference (today): $today.",
    );

    try {
      final allFiles = getAllVideos();

      // Converting to Date in order to sort
      final List<DateTime> allDates = [];
      for (int i = 0; i < allFiles.length; i++) {
        allDates.add(DateTime.parse(allFiles[i]));
      }

      if (allDates.isNotEmpty) {
        final DateTime oldest = allDates.reduce(
          (a, b) => a.isBefore(b) ? a : b,
        );
        final DateTime newest = allDates.reduce((a, b) => a.isAfter(b) ? a : b);
        logVerbose(
          '[Utils.getSelectedVideosFromStorage()] - Parsed ${allDates.length} video dates before filtering. '
          'Oldest: $oldest. Newest: $newest.',
        );
      } else {
        logVerbose(
          '[Utils.getSelectedVideosFromStorage()] - No video dates parsed from ${allFiles.length} file(s) found by getAllVideos().',
        );
      }

      switch (exportDateRange) {
        case ExportDateRange.last7Days:
          final last7Days = today.subtract(const Duration(days: 7));
          logVerbose(
            '[Utils.getSelectedVideosFromStorage()] - last7Days cutoff (keeping dates on/after): $last7Days',
          );
          for (int i = 0; i < allDates.length; i++) {
            allDates.removeWhere((e) => e.isBefore(last7Days));
          }
          break;
        case ExportDateRange.last30Days:
          final last30Days = today.subtract(const Duration(days: 30));
          logVerbose(
            '[Utils.getSelectedVideosFromStorage()] - last30Days cutoff (keeping dates on/after): $last30Days',
          );
          for (int i = 0; i < allDates.length; i++) {
            allDates.removeWhere((e) => e.isBefore(last30Days));
          }
          break;
        case ExportDateRange.last60Days:
          final last60Days = today.subtract(const Duration(days: 60));
          logVerbose(
            '[Utils.getSelectedVideosFromStorage()] - last60Days cutoff (keeping dates on/after): $last60Days',
          );
          for (int i = 0; i < allDates.length; i++) {
            allDates.removeWhere((e) => e.isBefore(last60Days));
          }
          break;
        case ExportDateRange.last90Days:
          final last90Days = today.subtract(const Duration(days: 90));
          logVerbose(
            '[Utils.getSelectedVideosFromStorage()] - last90Days cutoff (keeping dates on/after): $last90Days',
          );
          for (int i = 0; i < allDates.length; i++) {
            allDates.removeWhere((e) => e.isBefore(last90Days));
          }
          break;
        case ExportDateRange.thisMonth:
          logVerbose(
            '[Utils.getSelectedVideosFromStorage()] - thisMonth range (keeping dates between): '
            '${DateTime(now.year, now.month)} and $now',
          );
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
          logVerbose(
            '[Utils.getSelectedVideosFromStorage()] - thisYear range (keeping dates between): '
            '${DateTime(now.year)} and $now',
          );
          for (int i = 0; i < allDates.length; i++) {
            // Retains all the dates from the start of the year until the current date within the year
            allDates.retainWhere(
              (e) =>
                  e.compareTo(DateTime(now.year)) >= 0 && e.compareTo(now) <= 0,
            );
          }
          break;
        case ExportDateRange.lastYear:
          logVerbose(
            '[Utils.getSelectedVideosFromStorage()] - lastYear range (keeping dates between): '
            '${DateTime(now.year - 1)} and ${DateTime(now.year)}',
          );
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
        // Nothing else needs to be done here
      }

      logVerbose(
        '[Utils.getSelectedVideosFromStorage()] - ${allDates.length} video date(s) remain after filtering for $exportDateRange.',
      );

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
    } catch (e, stackTrace) {
      logError(
        '[Utils.getSelectedVideosFromStorage()] - Error while filtering videos for $exportDateRange: $e',
      );
      logError(
        '[Utils.getSelectedVideosFromStorage()] - Stack trace: $stackTrace',
      );
    }

    logVerbose(
      '[Utils.getSelectedVideosFromStorage()] - Returning ${allVideos.length} video(s) for $exportDateRange.',
    );
    return allVideos;
  }

  static Future<String> copyFontToStorage() async {
    final String fontPath = '${AppPaths.internal}/magic.ttf';
    try {
      if (StorageUtils.checkFileExists(fontPath)) {
        logInfo('Text font for ffmpeg already exists, not copying it.');
      } else {
        final ByteData data = await rootBundle.load(
          'assets/fonts/YuseiMagic-Regular.ttf',
        );
        final List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await io.File(fontPath).writeAsBytes(bytes);
        logInfo('Text font for ffmpeg copied to $fontPath');
      }
    } catch (e) {
      logError(e);
    }

    return fontPath;
  }

  /// Get the string with correct format for the location metadata
  static String locationPositionToString(double? value) {
    if (value == null) return '+0';

    final String stringValue = value.toString();
    if (stringValue.startsWith('-')) {
      return stringValue;
    }
    return '+$stringValue';
  }
}
