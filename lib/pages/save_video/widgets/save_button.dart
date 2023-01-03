import 'dart:convert';
import 'dart:developer';

import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/utils/theme.dart';
import 'package:saf/saf.dart';
import 'package:video_player/video_player.dart';

import '../../../controllers/daily_entry_controller.dart';
import '../../../controllers/video_count_controller.dart';
import '../../../routes/app_pages.dart';
import '../../../utils/constants.dart';
import '../../../utils/custom_dialog.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/ffmpeg_api_wrapper.dart';
import '../../../utils/shared_preferences_util.dart';
import '../../../utils/storage_utils.dart';
import '../../../utils/utils.dart';

class SaveButton extends StatefulWidget {
  SaveButton({
    required this.videoPath,
    required this.videoController,
    required this.dateColor,
    required this.dateFormat,
    required this.isTextDate,
    required this.userLocation,
    required this.subtitles,
    required this.videoDuration,
    required this.isGeotaggingEnabled,
    required this.textOutlineColor,
    required this.textOutlineWidth,
    required this.videoStartInMilliseconds,
    required this.videoEndInMilliseconds,
  });

  // Finding controllers
  final String videoPath;
  final VideoPlayerController videoController;
  final Color dateColor;
  final String dateFormat;
  final bool isTextDate;
  final String? userLocation;
  final String? subtitles;
  final int videoDuration;
  final bool isGeotaggingEnabled;
  final Color textOutlineColor;
  final double textOutlineWidth;
  final double videoStartInMilliseconds;
  final double videoEndInMilliseconds;

  @override
  _SaveButtonState createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  final String logTag = '[SAVE RECORDING] - ';
  bool isProcessing = false;
  bool canDistortVideo = false;
  String currentProfileName = 'Default';

  final DailyEntryController _dayController = Get.find();

  final VideoCountController _videoCountController = Get.find();

  void _saveVideo() async {
    Utils.logInfo('${logTag}Starting to edit ${widget.videoPath} with ffmpeg');
    setState(() {
      isProcessing = true;
    });

    try {
      final bool isVideoValid = await _validateInputVideo(context);
      if (isVideoValid) {
        log('Video is valid! 🎉');
        await _editWithFFmpeg(widget.isGeotaggingEnabled, context);
      }
      setState(() {
        isProcessing = false;
      });
    } catch (e) {
      Utils.logError(logTag + e.toString());
      setState(() {
        isProcessing = false;
      });
      // Showing error popup
      await showDialog(
        barrierDismissible: false,
        context: Get.context!,
        builder: (context) => CustomDialog(
          isDoubleAction: false,
          title: 'saveVideoErrorTitle'.tr,
          content: '${'tryAgainMsg'.tr}\n\nError: ${e.toString()}',
          actionText: 'Ok',
          actionColor: Colors.red,
          action: () => Get.offAllNamed(Routes.HOME),
          sendLogs: true,
        ),
      );
    } finally {
      // Deleting video from cache
      // StorageUtils.deleteFile(widget.videoPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool _pressedSave = false;

    return FloatingActionButton(
      backgroundColor: Colors.green,
      child: !isProcessing
          ? const Icon(
              Icons.save,
              color: Colors.white,
            )
          : const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white,
              ),
            ),
      onPressed: () {
        // Prevents user from clicking it twice
        if (!_pressedSave) {
          _pressedSave = true;
          _saveVideo();
        }
      },
    );
  }

  // Check if user is using a custom profile to determine the output path of the video
  String getVideoOutputPath() {
    String videoOutputPath = '';
    final String defaultOutputPath =
        '${SharedPrefsUtil.getString('appPath')}${widget.dateFormat}.mp4';

    final selectedProfileIndex = SharedPrefsUtil.getInt('selectedProfileIndex') ?? 0;
    if (selectedProfileIndex == 0) {
      // If this is true, it means we are using the default profile, so the output folder would be the default output path
      videoOutputPath = defaultOutputPath;
    } else {
      // This means we are using a custom profile
      final allProfiles = SharedPrefsUtil.getStringList('profiles');
      if (allProfiles != null) {
        setState(() {
          currentProfileName = allProfiles[selectedProfileIndex];
        });

        videoOutputPath =
            '${SharedPrefsUtil.getString('appPath')}Profiles/$currentProfileName/${DateFormatUtils.getToday()}.mp4';
      }
    }
    return videoOutputPath;
  }

  // Ensure the video passes all validations before processing
  Future<bool> _validateInputVideo(BuildContext context) async {
    final videoPath = widget.videoPath;

    return await executeFFprobe(
            '-v error -print_format json -show_format -select_streams v:0 -show_streams $videoPath')
        .then((session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        final sessionLog = await session.getOutput();
        if (sessionLog == null) return false;
        final Map<String, dynamic> videoStreamDetails = jsonDecode(sessionLog)['streams'][0];

        final num videoWidth = videoStreamDetails['width'];
        final num videoHeight = videoStreamDetails['height'];

        // Check for video orientation before saving video.
        // In some videos, the rotation property is not explicity defined which will cause ffprobe to return a null value,
        // so the workaround here compares the values of video width & height to determine the orientation

        // The orientation is always portrait whenever the video height is greater than the video width
        if (videoHeight > videoWidth) {
          await _showPortraitModeErrorDialog();
          return false;
        }

        // Check for video aspect ratio before saving video.
        // In some videos, the DAP/SAP (display/sample aspect ratio) properties are not explicity defined which will cause ffprobe to return a null value,
        // so the workaround here uses the video width & height to determine the aspect ratio
        final num videoAspectRatio = (videoWidth / videoHeight).toPrecision(2);

        // 1.78 is the decimal equivalent of 16:9 aspect ratio videos
        if (videoAspectRatio != 1.78) {
          final returnVal = await _showAspectRatioWarningDialog();
          // If the user closes the dialog without selecting a value, cancel video validation
          if (returnVal == null) return false;
          return true;
        }

        return true;
      }
      return false;
    });
  }

  Future<void> _editWithFFmpeg(bool isGeotaggingEnabled, BuildContext context) async {
    // Positions to render texts for the (x, y co-ordinates)
    // According to the ffmpeg docs, the x, y positions are relative to the top-left side of the output frame.
    final String datePosY = widget.isTextDate ? 'h-th-40' : '40';
    final String datePosX = widget.isTextDate ? '40' : 'w-tw-40';
    const String locPosY = 'h-th-40';
    const String locPosX = 'w-tw-40';

    const double dateTextSize = 40;
    const double locTextSize = 40;

    String locOutput = '';

    // Used to not increment videoCount controller
    bool isEdit = false;

    // Copies text font for ffmpeg to storage if it was not copied yet
    final String fontPath = await Utils.copyFontToStorage();
    final String videoPath = widget.videoPath;

    // Parses the color code to a hex code format which can be read by ffmpeg
    final String parsedDateColor =
        '0x${widget.dateColor.value.toRadixString(16).substring(2)}';
    final String parsedTextOutlineColor =
        '0x${widget.textOutlineColor.value.toRadixString(16).substring(2)}';

    // Path to save the final video
    final String finalPath = getVideoOutputPath();
    Utils.logInfo('${logTag}Video will be saved to: $finalPath');

    // Check if video already exists and delete it if so (Edit daily feature)
    if (StorageUtils.checkFileExists(finalPath)) {
      Utils.logInfo('${logTag}Video already exists, deleting it to perform edit.');
      isEdit = true;
      StorageUtils.deleteFile(finalPath);
    }

    // Checks to ensure special read/write permissions with storage access framework
    final hasSafDirPerms = await Saf.isPersistedPermissionDirectoryFor(finalPath) ?? false;
    if (hasSafDirPerms) {
      await Saf(finalPath).getDirectoryPermission(isDynamic: true);
    }

    // If geotagging is enabled, we can allow the command to render the location text into the video
    if (isGeotaggingEnabled) {
      locOutput =
          ', drawtext=$fontPath:text=\'${widget.userLocation}\':fontsize=$locTextSize:fontcolor=\'$parsedDateColor\':borderw=${widget.textOutlineWidth}:bordercolor=$parsedTextOutlineColor:x=$locPosX:y=$locPosY';
    }

    // If subtitles TextBox were not left empty, we can allow the command to render the subtitles into the video, otherwise we add empty subtitles to populate the streams with a subtitle stream, so that concat demuxer can work properly when creating a movie
    String subtitlesPath = '';
    if (widget.subtitles != null && widget.subtitles != '') {
      subtitlesPath = await Utils.writeSrt(
        widget.subtitles!,
        widget.videoDuration,
      );
    } else {
      Utils.logInfo('${logTag}Subtitles TextField was left empty. Adding empty subtitles...');
      subtitlesPath = await Utils.writeSrt('', 0);
    }
    Utils.logInfo('${logTag}Subtitles file path: $subtitlesPath');

    // Checks if we can distort the video
    String distortCommand = '';
    if (canDistortVideo) {
      distortCommand = ',setsar=1';
    } else {
      distortCommand = '';
    }

    final subtitles = '-i $subtitlesPath -c copy -c:s mov_text';
    final metadata =
        '-metadata artist="${Constants.artist}" -metadata album="$currentProfileName"';
    final trimCommand =
        '-ss ${widget.videoStartInMilliseconds}ms -to ${widget.videoEndInMilliseconds}ms';

    // Caches the default font to save texts in ffmpeg.
    // The edit may fail unexpectedly in some devices if this is not done.
    await FFmpegKitConfig.setFontDirectory(fontPath);

    // Edit and save video
    final command =
        '-i $videoPath $subtitles $metadata -vf [in]scale=1920:1080$distortCommand,drawtext="$fontPath:text=\'${widget.dateFormat}\':fontsize=$dateTextSize:fontcolor=\'$parsedDateColor\':borderw=${widget.textOutlineWidth}:bordercolor=$parsedTextOutlineColor:x=$datePosX:y=$datePosY$locOutput[out]" $trimCommand -c:a aac -b:a 256k -codec:v libx264 -pix_fmt yuv420p $finalPath -y';
    await executeFFmpeg(command).then((session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        Utils.logInfo('${logTag}Video edited successfully');

        _dayController.updateDaily();

        // Updates the controller: videoCount += 1
        if (!isEdit) {
          _videoCountController.updateVideoCount();
        }

        // Showing confirmation popup
        showDialog(
          barrierDismissible: false,
          context: Get.context!,
          builder: (context) => CustomDialog(
            isDoubleAction: false,
            title: 'videoSavedTitle'.tr,
            content: 'videoSavedDesc'.tr,
            actionText: 'Ok',
            actionColor: Colors.green,
            action: () => Get.offAllNamed(Routes.HOME),
          ),
        );
      } else if (ReturnCode.isCancel(returnCode)) {
        Utils.logInfo('${logTag}Execution was cancelled');
      } else {
        Utils.logError(
            '${logTag}Error editing video: Return code is ${await session.getReturnCode()}');
        final sessionLog = await session.getLogsAsString();
        final failureStackTrace = await session.getFailStackTrace();
        Utils.logError('${logTag}Session log is: $sessionLog');
        Utils.logError('${logTag}Failure stacktrace: $failureStackTrace');
        await showDialog(
          barrierDismissible: false,
          context: Get.context!,
          builder: (context) => CustomDialog(
            isDoubleAction: false,
            title: 'saveVideoErrorTitle'.tr,
            content: '${'tryAgainMsg'.tr}\n\nError: $sessionLog',
            actionText: 'Ok',
            actionColor: Colors.red,
            action: () => Get.offAllNamed(Routes.HOME),
            sendLogs: true,
          ),
        );
      }
    });
  }

  Future<bool?> _showAspectRatioWarningDialog() async {
    return await showDialog<bool?>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        title: Text(
          'videoResolutionTitle'.tr,
        ),
        content: Text(
          'videoResolutionWarning'.tr,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              setState(() {
                canDistortVideo = false;
              });
              Navigator.pop(context);
              return Future.value(false);
            },
            style: TextButton.styleFrom(
              foregroundColor: ThemeService().isDarkTheme() ? AppColors.light : AppColors.dark,
            ),
            child: Text('skip'.tr),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                canDistortVideo = true;
              });
              Navigator.pop(context);
              return Future.value(true);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.green,
            ),
            child: Text('yes'.tr),
          )
        ],
      ),
    );
  }

  Future<void> _showPortraitModeErrorDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        title: Text(
          'oops'.tr,
        ),
        content: Text(
          'unsupportedPortraitMode'.tr,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.green,
            ),
            child: Text('ok'.tr),
          )
        ],
      ),
    );
  }
}
