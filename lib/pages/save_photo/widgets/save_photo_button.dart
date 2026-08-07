import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../../controllers/daily_entry_controller.dart';
import '../../../routes/app_pages.dart';
import '../../../utils/app_paths.dart';
import '../../../utils/constants.dart';
import '../../../utils/custom_dialog.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/ffmpeg_api_wrapper.dart';
import '../../../utils/shared_preferences_util.dart';
import '../../../utils/storage_utils.dart';
import '../../../utils/utils.dart';
import '../../../utils/video_encoder.dart';

class SavePhotoButton extends StatefulWidget {
  SavePhotoButton({
    required this.photoPath,
    this.photoDurationInSeconds = 1,
    required this.dateColor,
    required this.dateFormat,
    required this.isTextDate,
    required this.userPosition,
    required this.userLocation,
    required this.subtitles,
    required this.isGeotaggingEnabled,
    required this.textOutlineColor,
    required this.textOutlineWidth,
    required this.determinedDate,
  });

  final String photoPath;
  final int photoDurationInSeconds;
  final Color dateColor;
  final String dateFormat;
  final bool isTextDate;
  final Position? userPosition;
  final String? userLocation;
  final String? subtitles;
  final bool isGeotaggingEnabled;
  final Color textOutlineColor;
  final double textOutlineWidth;
  final DateTime determinedDate;

  @override
  _SavePhotoButtonState createState() => _SavePhotoButtonState();
}

class _SavePhotoButtonState extends State<SavePhotoButton> {
  final String logTag = '[SAVE PHOTO AS VIDEO] - ';
  String currentProfileName = 'Default';
  ValueNotifier<num> saveProgressPercentage = ValueNotifier(0);

  final DailyEntryController _dayController = Get.find();

  void _savePhoto() async {
    Utils.logInfo('${logTag}Starting to process ${widget.photoPath} with ffmpeg');

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
          action: () => Get.offAllNamed(Routes.HOME)?.then((_) {
            if (mounted) setState(() {});
          }),
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
          _savePhoto();
        }
      },
    );
  }

  void showProgressDialog() async {
    return await showDialog(
      context: Get.context!,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
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
                    '${value.toStringAsFixed(1)}%',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    backgroundColor: AppColors.green.withValues(alpha: 0.2),
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
    final String videoName = DateFormatUtils.getDate(widget.determinedDate);

    final selectedProfileIndex = SharedPrefsUtil.getInt('selectedProfileIndex') ?? 0;
    if (selectedProfileIndex == 0) {
      // Default profile, videos go straight into the app folder.
      return '${AppPaths.videos}$videoName.mp4';
    }

    final allProfiles = SharedPrefsUtil.getStringList('profiles');
    if (allProfiles == null || selectedProfileIndex >= allProfiles.length) {
      Utils.logWarning('${logTag}Unknown profile index $selectedProfileIndex, using the default');
      return '${AppPaths.videos}$videoName.mp4';
    }

    setState(() {
      currentProfileName = allProfiles[selectedProfileIndex];
    });
    return '${AppPaths.profileVideos(currentProfileName)}$videoName.mp4';
  }

  Future<void> _editWithFFmpeg(bool isGeotaggingEnabled, BuildContext context) async {
    // Positions to render texts for the (x, y co-ordinates)
    final String datePosY = widget.isTextDate ? 'h-th-40' : '40';
    final String datePosX = widget.isTextDate ? '40' : 'w-tw-40';
    const String locPosY = 'h-th-40';
    const String locPosX = 'w-tw-40';

    const double dateTextSize = 40;
    const double locTextSize = 40;

    String locale = '';

    // Copies text font for ffmpeg to storage if it was not copied yet
    final String fontPath = await Utils.copyFontToStorage();
    final String photoPath = widget.photoPath;

    // Parses the color code to a hex code format which can be read by ffmpeg
    String parsedDateColor = '';
    String parsedTextOutlineColor = '';

    try {
      parsedDateColor = '0x${widget.dateColor.toARGB32().toRadixString(16).substring(2)}';
      parsedTextOutlineColor = '0x${widget.textOutlineColor.toARGB32().toRadixString(16).substring(2)}';
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
            action: () async {
              Utils.logInfo('${logTag}Video already exists, deleting it to perform edit.');
              try {
                await StorageUtils.deleteVideo(finalPath);
              } finally {
                Get.back();
              }
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

    if (!shouldContinue) return;

    // The font name map must not be omitted: a null map reaches the iOS side
    // of ffmpeg-kit as NSNull, which crashes on [NSNull allKeys].
    await FFmpegKitConfig.setFontDirectory(fontPath, {});

    if (isGeotaggingEnabled) {
      final String locationTextFilePath = await Utils.writeLocationTxt(widget.userLocation);
      locale =
          ', drawtext=textfile=$locationTextFilePath:fontfile=$fontPath:fontsize=$locTextSize:fontcolor=\'$parsedDateColor\':borderw=${widget.textOutlineWidth}:bordercolor=$parsedTextOutlineColor:x=$locPosX:y=$locPosY';
    }

    // We are generating a video from a photo, so we add a silent audio track
    const String audioStream = '-f lavfi -i anullsrc=channel_layout=mono:sample_rate=48000';
    const String audioMap = '-map 2:a';
    const String origin = 'gallery_photo';

    String subtitlesPath = '';
    const int videoStartInMilliseconds = 0;
    final int videoEndInMilliseconds = widget.photoDurationInSeconds * 1000;
    if (widget.subtitles?.isEmpty == false) {
      subtitlesPath = await Utils.writeSrt(
        widget.subtitles!,
        videoStartInMilliseconds,
        videoEndInMilliseconds,
      );
    } else {
      Utils.logInfo('${logTag}Subtitles TextField was left empty. Adding empty subtitles...');
      subtitlesPath = await Utils.writeSrt('', 0, videoEndInMilliseconds);
    }
    Utils.logInfo('${logTag}Subtitles file path: $subtitlesPath');

    String locationMetadata = '';
    if (isGeotaggingEnabled) {
      final latitude = Utils.locationPositionToString(widget.userPosition?.latitude);
      final longitude = Utils.locationPositionToString(widget.userPosition?.longitude);
      final localeName = widget.userLocation?.replaceAll('"', '\\"');
      locationMetadata = ' -metadata location="$latitude$longitude/$localeName"';
    }

    final baseMetadata =
        '-metadata artist="${Constants.artist}" -metadata album="$currentProfileName" -metadata comment="origin=$origin"';

    final metadata = baseMetadata + locationMetadata;

    // Scale video to 1920x1080 and add black padding if needed
    const scale =
        'scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black';

    // Add date to the video
    final date =
        ',drawtext="$fontPath:text=\'${widget.dateFormat}\':fontsize=$dateTextSize:fontcolor=\'$parsedDateColor\':borderw=${widget.textOutlineWidth}:bordercolor=$parsedTextOutlineColor:x=$datePosX:y=$datePosY';

    // Add subtitles to the video
    final String subtitles = widget.subtitles?.isEmpty == false
        ? '-c:s mov_text -map 1:v $audioMap -map 0:s -disposition:s:0 default'
        : '-map 1:v $audioMap';

    // Framerate 30, mono 48 kHz aac at 256k, yuv420p, and whichever H.264
    // encoder this build of ffmpeg actually ships (see VideoEncoder).
    final String defaultEditSettings =
        '-r 30 -ac 1 -ar 48000 -c:a aac -b:a 256k ${VideoEncoder.arguments} -pix_fmt yuv420p';

    // Full command to edit and save video
    final command =
        '-i "$subtitlesPath" -loop 1 -framerate 30 -i "$photoPath" $audioStream $metadata -vf [in]$scale$date$locale[out]" $defaultEditSettings -t ${widget.photoDurationInSeconds} $subtitles "$finalPath" -y';

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
                Get.offAllNamed(
                  Routes.HOME,
                  arguments: {'forcedDate': widget.determinedDate},
                )?.then((_) {
                  if (mounted) setState(() {});
                });
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
              action: () => Get.offAllNamed(Routes.HOME)?.then((_) {
                if (mounted) setState(() {});
              }),
            ),
          );
        }
      },
      statisticsCallback: (statistics) async {
        if (statistics.getTime() > 0) {
          num tempProgressValue =
              (statistics.getTime() / (widget.photoDurationInSeconds * 1000)) * 100;
          if (tempProgressValue >= 100) {
            tempProgressValue = 99.9;
          }
          saveProgressPercentage.value = tempProgressValue;
        }
      },
    );
  }
}
