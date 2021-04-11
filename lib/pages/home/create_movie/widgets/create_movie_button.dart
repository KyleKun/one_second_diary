import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/controllers/video_count_controller.dart';
import 'package:one_second_diary/utils/constants.dart';
import 'package:one_second_diary/utils/custom_dialog.dart';
import 'package:one_second_diary/utils/ffmpeg_api_wrapper.dart';
import 'package:one_second_diary/utils/utils.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';

class CreateMovieButton extends StatefulWidget {
  @override
  _CreateMovieButtonState createState() => _CreateMovieButtonState();
}

class _CreateMovieButtonState extends State<CreateMovieButton> {
  VideoCountController _movieCount = Get.find();
  bool isProcessing = false;
  void _createMovie() async {
    setState(() {
      isProcessing = true;
    });
    try {
      // Creates the folder if it is not created yet
      Utils.createFolder();

      final allVideos = Utils.getAllVideosFromStorage();

      // Needs more than 1 video to create movie
      if (allVideos.length < 2) {
        showDialog(
          context: Get.context,
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

        // Creating txt that will be used with ffmpeg
        String txtPath = await Utils.writeTxt(allVideos);
        String outputPath = StorageUtil.getString('moviesPath') +
            'OneSecondDiary-Movie-${_movieCount.movieCount.value}-${Utils.getToday()}.mp4';

        await executeFFmpeg(
                '-f concat -safe 0 -i $txtPath -map 0 -c copy $outputPath')
            .then((result) {
          if (result == 0) {
            _movieCount.updateMovieCount();
            showDialog(
              context: Get.context,
              builder: (context) => CustomDialog(
                isDoubleAction: false,
                title: 'movieCreatedTitle'.tr,
                content: 'movieCreatedDesc'.tr,
                actionText: 'Ok',
                actionColor: Colors.green,
                action: () => Get.back(),
              ),
            );
            // Utils().logInfo('Video saved in gallery in the folder OSD-Movies!');

          } else {
            showDialog(
              context: Get.context,
              builder: (context) => CustomDialog(
                isDoubleAction: false,
                title: 'movieError'.tr,
                content: 'tryAgainMsg'.tr,
                actionText: 'Ok',
                actionColor: Colors.red,
                action: () => Get.back(),
              ),
            );
          }
        });
      }
    } catch (e) {
      // Utils().logError('$e');
      showDialog(
        context: Get.context,
        builder: (context) => CustomDialog(
          isDoubleAction: false,
          title: 'movieError'.tr,
          content: 'tryAgainMsg'.tr,
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
          primary: AppColors.mainColor,
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
            : CircularProgressIndicator(
                valueColor: new AlwaysStoppedAnimation<Color>(
                  Colors.white,
                ),
              ),
      ),
    );
  }
}
