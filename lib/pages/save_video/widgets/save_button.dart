import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saf/saf.dart';
import 'package:video_player/video_player.dart';

import '../../../controllers/daily_entry_controller.dart';
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
    required this.determinedDate,
    required this.isFromRecordingPage,
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
  final DateTime determinedDate;
  final bool isFromRecordingPage;

  @override
  _SaveButtonState createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  final String logTag = '[SAVE RECORDING] - ';
  String currentProfileName = 'Default';
  ValueNotifier<num> saveProgressPercentage = ValueNotifier(0);

  final DailyEntryController _dayController = Get.find();

  void _saveVideo() async {
    Utils.logInfo('${logTag}Starting to edit ${widget.videoPath} with ffmpeg');

    try {
      await _editWithFFmpeg(widget.isGeotaggingEnabled, context);
    } catch (e) {
      Utils.logError(logTag + e.toString());
      // Showing error popup
      await showDialog(
        barrierDismissible: false,
        context: Get.context!,
        builder: (context) => CustomDialog(
          isDoubleAction: false,
          title: 'saveVideoErrorTitle'.tr,
          content: '${'tryAgainMsg'.tr}',
          actionText: 'Ok',
          actionColor: Colors.red,
          action: () => Get.offAllNamed(Routes.HOME)?.then((_) => setState(() {})),
          sendLogs: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool _pressedSave = false;

    return FloatingActionButton(
      backgroundColor: AppColors.green,
      child: const Icon(
        Icons.save,
        color: Colors.white,
      ),
      onPressed: () {
        // Prevents user from clicking it twice
        if (!_pressedSave) {
          _pressedSave = true;
          showProgressDialog();
          _saveVideo();
        }
      },
    );
  }

  void showProgressDialog() async {
    return await showDialog(
      context: Get.context!,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: ValueListenableBuilder(
          valueListenable: saveProgressPercentage,
          builder: (context, value, child) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            title: Text(
              'processingVideo'.tr,
              textAlign: TextAlign.center,
            ),
            content: Padding(
              padding: const EdgeInsets.only(bottom: 21.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$value%',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    backgroundColor: AppColors.green.withOpacity(0.2),
                    color: AppColors.green,
                    minHeight: 16,
                    value: (value / 100).toDouble(),
                  ),
                  const SizedBox(height: 15),
                  Text('doNotCloseTheApp'.tr),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Check if user is using a custom profile to determine the output path of the video
  String getVideoOutputPath() {
    String videoOutputPath = '';
    final String videoName = DateFormatUtils.getDate(widget.determinedDate);
    final String defaultOutputPath = '${SharedPrefsUtil.getString('appPath')}$videoName.mp4';

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
            '${SharedPrefsUtil.getString('appPath')}Profiles/$currentProfileName/$videoName.mp4';
      }
    }
    return videoOutputPath;
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

    String locale = '';

    // Copies text font for ffmpeg to storage if it was not copied yet
    final String fontPath = await Utils.copyFontToStorage();
    final String videoPath = widget.videoPath;

    // Parses the color code to a hex code format which can be read by ffmpeg
    String parsedDateColor = '';
    String parsedTextOutlineColor = '';

    try {
      parsedDateColor = '0x${widget.dateColor.value.toRadixString(16).substring(2)}';
      parsedTextOutlineColor = '0x${widget.textOutlineColor.value.toRadixString(16).substring(2)}';
    } catch (e) {
      Utils.logError(logTag + e.toString());
      Utils.logInfo('Error parsing colors, applying default white.');
      parsedDateColor = '0xffffff';
      parsedTextOutlineColor = '0x000000';
    }

    // Path to save the final video
    final String finalPath = getVideoOutputPath();
    Utils.logInfo('${logTag}Video will be saved to: $finalPath');

    // Check if video already exists and delete it if so (Edit daily feature)
    bool shouldContinue = true;
    if (StorageUtils.checkFileExists(finalPath)) {
      await showDialog(
        barrierDismissible: false,
        context: Get.context!,
        builder: (context) => CustomDialog(
            isDoubleAction: true,
            title: 'editQuestionTitle'.tr,
            content: 'editQuestion'.tr,
            actionText: 'yes'.tr,
            actionColor: AppColors.green,
            action: () {
              Utils.logInfo('${logTag}Video already exists, deleting it to perform edit.');
              StorageUtils.deleteFile(finalPath);
              Get.back();
            },
            action2Text: 'no'.tr,
            action2Color: Colors.red,
            action2: () {
              Utils.logInfo('${logTag}User chose not to edit video.');
              shouldContinue = false;
              Get.back();
              Get.back();
            }),
      );
    }

    // If the video already exists and the user chose not to edit it, we can stop the process here
    if (!shouldContinue) return;

    // Caches the default font to save texts in ffmpeg.
    // The edit may fail unexpectedly in some devices if this is not done.
    await FFmpegKitConfig.setFontDirectory(fontPath);

    // Checks to ensure special read/write permissions with storage access framework
    final hasSafDirPerms = await Saf.isPersistedPermissionDirectoryFor(finalPath) ?? false;
    if (hasSafDirPerms) {
      await Saf(finalPath).getDirectoryPermission(isDynamic: true);
    }

    // If geotagging is enabled, we can allow the command to render the location text into the video
    if (isGeotaggingEnabled) {
      final String locationTextFilePath = await Utils.writeLocationTxt(widget.userLocation);
      locale =
          ', drawtext=textfile=$locationTextFilePath:fontfile=$fontPath:fontsize=$locTextSize:fontcolor=\'$parsedDateColor\':borderw=${widget.textOutlineWidth}:bordercolor=$parsedTextOutlineColor:x=$locPosX:y=$locPosY';
    }

    // Check if video was added from gallery and has an audio stream, adding one if not (screen recordings can be muted for example)
    String audioStream = '';
    String origin = 'osd_recording';
    if (!widget.isFromRecordingPage) {
      origin = 'gallery';
      await executeFFprobe(
              '-v quiet -select_streams a:0 -show_entries stream=codec_type -of default=nw=1:nk=1 "$videoPath"')
          .then((session) async {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          final sessionLog = await session.getOutput();
          if (sessionLog == null || sessionLog.isEmpty) {
            Utils.logWarning('${logTag}Video has no audio stream, adding one.');
            audioStream = '-f lavfi -i anullsrc=channel_layout=mono:sample_rate=48000 -shortest';
          }
        }
      });
    }

    // If subtitles TextBox were not left empty, we can allow the command to render the subtitles into the video, otherwise we add empty subtitles to populate the streams with a subtitle stream, so that concat demuxer can work properly when creating a movie
    String subtitlesPath = '';
    if (widget.subtitles?.isEmpty == false) {
      subtitlesPath = await Utils.writeSrt(
        widget.subtitles!,
        widget.videoEndInMilliseconds - widget.videoStartInMilliseconds,
      );
    } else {
      Utils.logInfo('${logTag}Subtitles TextField was left empty. Adding empty subtitles...');
      subtitlesPath = await Utils.writeSrt('', 0);
    }
    Utils.logInfo('${logTag}Subtitles file path: $subtitlesPath');

    // Add metadata to know the version of the app it was made, profile it was saved to and the origin of the video
    final metadata =
        '-metadata artist="${Constants.artist}" -metadata album="$currentProfileName" -metadata comment="origin=$origin"';

    // Trim video to the selected range
    final trim = '-ss ${widget.videoStartInMilliseconds}ms -to ${widget.videoEndInMilliseconds}ms';

    // Scale video to 1920x1080 and add black padding if needed
    const scale =
        'scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black';

    // Add date to the video
    final date =
        ',drawtext="$fontPath:text=\'${widget.dateFormat}\':fontsize=$dateTextSize:fontcolor=\'$parsedDateColor\':borderw=${widget.textOutlineWidth}:bordercolor=$parsedTextOutlineColor:x=$datePosX:y=$datePosY';

    // Add subtitles to the video
    const subtitles = '-c:s mov_text -map 1:v -map 1:a? -map 0:s -disposition:s:0 default';

    // Apply default edit settings: framerate 30, audio channels 1, audio rate 48000, audio bitrate 256k, video codec libx264, pixel format yuv420p, crf 20, preset slow
    const defaultEditSettings =
        '-r 30 -ac 1 -ar 48000 -c:a aac -b:a 256k -c:v libx264 -pix_fmt yuv420p -crf 20 -preset slow';

    // Full command to edit and save video
    final command =
        '-i "$subtitlesPath" -i "$videoPath" $audioStream $metadata -vf [in]$scale$date$locale[out]" $trim $defaultEditSettings $subtitles "$finalPath" -y';

    Utils.logInfo('${logTag}FFmpeg full command: $command');

    await executeAsyncFFmpeg(
      command,
      completeCallback: (session) async {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          Utils.logInfo('${logTag}Video edited successfully');

          if (widget.determinedDate.difference(DateTime.now()).inDays == 0) {
            _dayController.updateDaily();
          }

          Utils.updateVideoCount(showSnackBar: false);

          // Showing confirmation popup
          showDialog(
            barrierDismissible: false,
            context: Get.context!,
            builder: (context) => CustomDialog(
              isDoubleAction: false,
              title: 'videoSavedTitle'.tr,
              content: 'videoSavedDesc'.tr,
              actionText: 'Ok',
              actionColor: AppColors.green,
              action: () {
                final isExperimentalPicker =
                    SharedPrefsUtil.getBool('useExperimentalPicker') ?? true;
                // Deleting video from cache for recording page, or if experimental picker is disabled since experimental uses the source video
                if (widget.isFromRecordingPage || !isExperimentalPicker) {
                  StorageUtils.deleteFile(widget.videoPath);
                }
                Get.offAllNamed(
                  Routes.HOME,
                  arguments:
                      widget.isFromRecordingPage ? null : {'forcedDate': widget.determinedDate},
                )?.then((_) => setState(() {}));
              },
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

          // Make sure no incomplete files were left in the folder
          StorageUtils.deleteFile(finalPath);

          await showDialog(
            barrierDismissible: false,
            context: Get.context!,
            builder: (context) => CustomDialog(
              isDoubleAction: false,
              title: 'saveVideoErrorTitle'.tr,
              content: '${'tryAgainMsg'.tr}',
              actionText: 'Ok',
              actionColor: Colors.red,
              sendLogs: true,
              action: () => Get.offAllNamed(Routes.HOME)?.then((_) => setState(() {})),
            ),
          );
        }
      },
      statisticsCallback: (statistics) async {
        final totalVideoDuration =
            (widget.videoEndInMilliseconds - widget.videoStartInMilliseconds) ~/ 1000;
        // Determines the currently processed percentage of the video
        if (statistics.getTime() > 0) {
          num tempProgressValue = (statistics.getTime() ~/ totalVideoDuration) / 10;
          // Ideally the value should not exceed 100%, but the output also considers milliseconds so we estimate to 100.
          if (tempProgressValue >= 100) {
            tempProgressValue = 99.9;
          }
          saveProgressPercentage.value = tempProgressValue;
        }
      },
    );
  }
}
