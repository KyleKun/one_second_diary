import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';

import '../../../../controllers/video_count_controller.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/custom_dialog.dart';
import '../../../../utils/date_format_utils.dart';
import '../../../../utils/ffmpeg_api_wrapper.dart';
import '../../../../utils/shared_preferences_util.dart';
import '../../../../utils/storage_utils.dart';
import '../../../../utils/utils.dart';

class CreateMovieButton extends StatefulWidget {
  @override
  _CreateMovieButtonState createState() => _CreateMovieButtonState();
}

class _CreateMovieButtonState extends State<CreateMovieButton> {
  final VideoCountController _movieCount = Get.find();
  bool isProcessing = false;

  void _openVideo(String filePath) async {
    Get.back();
    await OpenFile.open(filePath);
  }

  void _createMovie() async {
    // Creates the folder if it is not created yet
    StorageUtils.createFolder();

    setState(() {
      isProcessing = true;
    });
    try {
      final allVideos = Utils.getAllVideosFromStorage();

      // Needs more than 1 video to create movie
      if (allVideos.length < 2) {
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
        final String txtPath = await Utils.writeTxt(allVideos);
        // Utils().logInfo('Saved txt');
        final String outputPath =
            '${SharedPrefsUtil.getString('moviesPath')}OneSecondDiary-Movie-${_movieCount.movieCount.value}-$today.mp4';
        // Utils().logInfo('It will be saved in: $outputPath');

        await executeFFmpeg('-f concat -safe 0 -i $txtPath -map 0 -c copy $outputPath -y').then(
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
                  action: () => _openVideo(outputPath),
                ),
              );
              // Utils().logInfo('Video saved in gallery in the folder OSD-Movies!');

            } else if (ReturnCode.isCancel(returnCode)) {
              print('Execution was cancelled');
            } else {
              // Utils().logError('$result');
              print('Error editing video: Return code is ${await session.getReturnCode()}');
              final sessionLog = await session.getAllLogsAsString();
              final failureStackTrace = await session.getFailStackTrace();
              debugPrint('Session lasted for ${await session.getDuration()} ms');
              debugPrint(session.getArguments().toString());
              debugPrint('Session log is $sessionLog');
              debugPrint('Failure stacktrace - $failureStackTrace');

              showDialog(
                barrierDismissible: false,
                context: Get.context!,
                builder: (context) => CustomDialog(
                  isDoubleAction: false,
                  title: 'movieError'.tr,
                  content: '${'tryAgainMsg'.tr}\nCode error: ${session.getFailStackTrace()}',
                  actionText: 'Ok',
                  actionColor: Colors.red,
                  action: () => Get.back(),
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
          action: () => Get.back(),
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
