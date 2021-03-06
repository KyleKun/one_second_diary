import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:get/get.dart';
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
  bool isProcessing = false;
  void _createMovie() async {
    setState(() {
      isProcessing = true;
    });
    try {
      final allVideos = Utils.getAllVideosFromStorage();

      // Needs more than 1 video to create movie
      if (allVideos.length < 2) {
        showDialog(
          context: Get.context,
          builder: (context) => CustomDialog(
            isDoubleAction: false,
            title: 'Movie was not created!',
            content:
                'You need to have 2 or more recorded videos in order to create a movie',
            actionText: 'Ok',
            actionColor: Colors.green,
            action: () => Get.back(),
          ),
        );
      } else {
        // Utils().logInfo('Creating movie with the following files: $allVideos');

        // Creating txt that will be used with ffmpeg
        String txtPath = await Utils.writeTxt(allVideos);
        String today = Utils.getToday();
        String outputPath = StorageUtil.getString('appPath') +
            'OneSecondDiary-Movie-$today.mp4';

        await executeFFmpeg(
            '-f concat -safe 0 -i $txtPath -map 0 -c copy $outputPath');
        // Utils().logInfo('Cache video saved at: $outputPath');

        GallerySaver.saveVideo(outputPath, albumName: 'OSD-Movies').then((_) {
          Utils.deleteFile(outputPath);
          // Utils().logInfo('Video saved in gallery in the folder OSD-Movies!');

          showDialog(
            context: Get.context,
            builder: (context) => CustomDialog(
              isDoubleAction: false,
              title: 'Movie created!',
              content: 'Video saved in gallery in OSD-Movies folder!',
              actionText: 'Ok',
              actionColor: Colors.green,
              action: () => Get.back(),
            ),
          );
        }, onError: (error) {
          // Utils().logError(error);
          showDialog(
            context: Get.context,
            builder: (context) => CustomDialog(
              isDoubleAction: false,
              title: 'Error copying movie to device!',
              content:
                  'Please try again. If the problem persists, contact the developer.',
              actionText: 'Ok',
              actionColor: Colors.red,
              action: () => Get.back(),
            ),
          );
        });
      }
    } catch (e) {
      // Utils().logError('$e');
      showDialog(
        context: Get.context,
        builder: (context) => CustomDialog(
          isDoubleAction: false,
          title: 'Error creating movie!',
          content:
              'Please try again. If the problem persists, contact the developer.',
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
                'Create',
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
