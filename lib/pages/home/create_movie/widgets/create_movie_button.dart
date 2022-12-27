import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../controllers/video_count_controller.dart';
import '../../../../enums/export_date_range.dart';
import '../../../../routes/app_pages.dart';
// import '../../../../enums/export_orientations.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/custom_dialog.dart';
import '../../../../utils/date_format_utils.dart';
import '../../../../utils/ffmpeg_api_wrapper.dart';
import '../../../../utils/shared_preferences_util.dart';
import '../../../../utils/storage_utils.dart';
import '../../../../utils/utils.dart';

class CreateMovieButton extends StatefulWidget {
  const CreateMovieButton({
    super.key,
    this.selectedExportDateRange,
    // required this.selectedOrientation,
    this.customSelectedVideos,
    this.customSelectedVideosIsSelected,
  });

  final ExportDateRange? selectedExportDateRange;
  // final ExportOrientation selectedOrientation;
  final List<String>? customSelectedVideos;
  final List<bool>? customSelectedVideosIsSelected;

  @override
  _CreateMovieButtonState createState() => _CreateMovieButtonState();
}

class _CreateMovieButtonState extends State<CreateMovieButton> {
  final VideoCountController _movieCount = Get.find();
  bool isProcessing = false;
  bool isCustom = false;

  // void _openVideo(String filePath) async {
  //   Get.back();
  //   await OpenFile.open(filePath);
  // }

  void _createMovie() async {
    // Creates the folder if it is not created yet
    StorageUtils.createFolder();

    setState(() {
      isProcessing = true;
    });
    try {
      final selectedExportDateRange = widget.selectedExportDateRange;
      final customSelectedVideos = widget.customSelectedVideos;
      List<String> selectedVideos = [];

      if (customSelectedVideos != null && customSelectedVideos.isNotEmpty) {
        isCustom = true;
        for (int i = 0; i < customSelectedVideos.length; i++) {
          if (widget.customSelectedVideosIsSelected![i]) {
            selectedVideos.add(customSelectedVideos[i]);
          }
        }
      } else {
        selectedVideos =
            Utils.getSelectedVideosFromStorage(selectedExportDateRange!);
      }

      // Needs more than 1 video to create movie
      if (selectedVideos.length < 2) {
        showDialog(
          barrierDismissible: false,
          context: Get.context!,
          builder: (context) => CustomDialog(
            isDoubleAction: false,
            title: 'movieErrorTitle'.tr,
            content: 'movieInsufficientVideos'.tr,
            actionText: 'Ok',
            actionColor: Colors.green,
            action: () => Get.back(),
          ),
        );
      } else {
        // Utils().logInfo('Creating movie with the following files: $allVideos');
        final String today = DateFormatUtils.getToday();

        // Creating txt that will be used with ffmpeg
        final String txtPath = await Utils.writeTxt(selectedVideos, isCustom);
        // Utils().logInfo('Saved txt');
        final String outputPath =
            '${SharedPrefsUtil.getString('moviesPath')}OneSecondDiary-Movie-${_movieCount.movieCount.value}-$today.mp4';
        // Utils().logInfo('It will be saved in: $outputPath');

        // Make sure all selected videos have a subtitles stream before creating movie
        for (String video in selectedVideos) {
          await executeFFprobe(
                  '-v quiet -select_streams s -show_streams $video')
              .then((session) async {
            final returnCode = await session.getReturnCode();
            if (ReturnCode.isSuccess(returnCode)) {
              final sessionLog = await session.getAllLogsAsString();
              debugPrint('\n\nStream info for $video --> $sessionLog\n\n');
              if (sessionLog == null || sessionLog.isEmpty) {
                debugPrint('No subtitles stream for $video, adding one...');
                final String tempPath = '${video.split('.mp4').first}_temp.mp4';
                final String subtitles = await Utils.writeSrt('', 0);
                final command =
                    '-i $video -i $subtitles -c copy -c:s mov_text $tempPath -y';
                await executeFFmpeg(command).then((session) async {
                  final returnCode = await session.getReturnCode();
                  if (ReturnCode.isSuccess(returnCode)) {
                    StorageUtils.deleteFile(video);
                    StorageUtils.renameFile(tempPath, video);
                    debugPrint('Added empty subtitles stream to $video');
                  } else {
                    debugPrint('Error adding subtitles stream to $video');
                  }
                });
              }
            }
          });
        }

        await executeFFmpeg(
                '-f concat -safe 0 -i $txtPath -map 0 -c copy $outputPath -y')
            .then(
          (session) async {
            final returnCode = await session.getReturnCode();
            if (ReturnCode.isSuccess(returnCode)) {
              _movieCount.updateMovieCount();
              showDialog(
                barrierDismissible: false,
                context: Get.context!,
                builder: (context) => CustomDialog(
                  isDoubleAction: false,
                  title: 'movieCreatedTitle'.tr,
                  content: 'movieCreatedDesc'.tr,
                  actionText: 'Ok',
                  actionColor: Colors.green,
                  // TODO: Video player screen showing movie
                  action: () => Get.offAllNamed(Routes.HOME),
                ),
              );
              // Utils().logInfo('Video saved in gallery in the folder OSD-Movies!');

            } else if (ReturnCode.isCancel(returnCode)) {
              debugPrint('Execution was cancelled');
            } else {
              // Utils().logError('$result');
              debugPrint(
                  'Error editing video: Return code is ${await session.getReturnCode()}');
              final sessionLog = await session.getAllLogsAsString();
              final failureStackTrace = await session.getFailStackTrace();
              debugPrint(
                  'Session lasted for ${await session.getDuration()} ms');
              debugPrint(session.getArguments().toString());
              debugPrint('Session log is $sessionLog');
              debugPrint('Failure stacktrace - $failureStackTrace');

              showDialog(
                barrierDismissible: false,
                context: Get.context!,
                builder: (context) => CustomDialog(
                  isDoubleAction: false,
                  title: 'movieError'.tr,
                  content:
                      '${'tryAgainMsg'.tr}\nCode error: ${session.getFailStackTrace()}',
                  actionText: 'Ok',
                  actionColor: Colors.red,
                  action: () => Get.offAllNamed(Routes.HOME),
                ),
              );
            }
          },
        );
      }
    } catch (e) {
      // Utils().logError('$e');
      showDialog(
        barrierDismissible: false,
        context: Get.context!,
        builder: (context) => CustomDialog(
          isDoubleAction: false,
          title: 'movieError'.tr,
          content: '${'tryAgainMsg'.tr}\n\nError: ${e.toString()}',
          actionText: 'Ok',
          actionColor: Colors.red,
          action: () => Get.offAllNamed(Routes.HOME),
        ),
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      height: MediaQuery.of(context).size.height * 0.08,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mainColor,
          elevation: 5.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(80.0),
          ),
        ),
        onPressed: () {
          if (!isProcessing) _createMovie();
        },
        child: !isProcessing
            ? Text(
                'create'.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: MediaQuery.of(context).size.width * 0.055,
                ),
              )
            : const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white,
                ),
              ),
      ),
    );
  }
}
