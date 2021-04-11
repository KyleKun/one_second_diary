import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/controllers/daily_entry_controller.dart';
import 'package:one_second_diary/controllers/lang_controller.dart';
import 'package:one_second_diary/controllers/video_count_controller.dart';
import 'package:one_second_diary/routes/app_pages.dart';
import 'package:one_second_diary/utils/custom_dialog.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';
import 'package:one_second_diary/utils/utils.dart';
import 'package:tapioca/tapioca.dart';

class SaveButton extends StatelessWidget {
  SaveButton({this.videoPath, this.videoController});

  // Finding controllers
  final DailyEntryController _dayController = Get.find();
  final VideoCountController _videoCountController = Get.find();
  final LanguageController _languageController = Get.find();

  // Video path from cache
  final String videoPath;
  final videoController;

  // Position x to render date
  final int x = 1120; // HiRes: 1690
  // Text size
  final int size = 25; // HiRes: 35
  final int y = 20;
  final Color color = Colors.black;

  // Edit the video, saves it in OneSecondDiary's folder and delete it from cache
  void _saveVideo(BuildContext context) async {
    // Used to not increment videoCount controller
    bool isEdit = false;

    try {
      // Utils().logInfo('Saving video...');

      // Creates the folder if it is not created yet
      Utils.createFolder();

      // Setting editing properties
      Cup cup = Cup(
        Content(videoPath),
        [
          TapiocaBall.textOverlay(
            // Date in the proper format
            Utils.getToday(
              isBr: _languageController.selectedLanguage.value == 'pt',
            ),
            x,
            y,
            size,
            color,
          ),
        ],
      );

      // Path to save the final video
      String finalPath =
          StorageUtil.getString('appPath') + Utils.getToday() + '.mp4';

      // Check if video already exists and delete it if so (Edit daily feature)
      if (Utils.checkFileExists(finalPath)) {
        isEdit = true;
        // Utils().logWarning('File already exists!');
        Utils.deleteFile(finalPath);
        // Utils().logWarning('Old file deleted!');
      }

      // Editing video
      await cup.suckUp(finalPath).then(
        (_) {
          // Utils().logInfo('Finished editing');

          _dayController.updateDaily();

          // Updates the controller: videoCount += 1
          if (!isEdit) {
            _videoCountController.updateVideoCount();
          }

          // Deleting video from cache
          Utils.deleteFile(videoPath);

          // Showing confirmation popup
          showDialog(
            context: Get.context,
            builder: (context) => CustomDialog(
              isDoubleAction: false,
              title: 'videoSavedTitle'.tr,
              content: 'videoSavedDesc'.tr,
              actionText: 'Ok',
              actionColor: Colors.green,
              action: () => Get.offAllNamed(Routes.HOME),
            ),
          );
        },
      );

      // Alternative way of editing video, using ffmpeg, but it is very slow
      // // Copies text font for ffmpeg to storage if it was not copied yet
      // String fontPath = await Utils.copyFontToStorage();

      // executeFFmpeg(
      //   '-i $videoPath -vf drawtext="$fontPath:text=\'$today\':fontsize=$size:fontcolor=\'Black\':x=$x:y=$y" -codec:v libx264 -crf 18 -preset slow -pix_fmt yuv420p $finalPath',
      // ).then((result) {
      //   if (result == 0) {
      //     Utils().logInfo('Sucess editing video');

      //     dayController.updateDaily();

      //     // Updates the controller: videoCount += 1
      //     if (!isEdit) {
      //       videoCountController.updateVideoCount();
      //     }

      //   } else {
      //     Utils().logError('Error editing video: $result');
      //   }
      // });

    } catch (e) {
      // Utils().logError('$e');
      // Showing error popup
      showDialog(
        context: Get.context,
        builder: (context) => CustomDialog(
          isDoubleAction: false,
          title: 'saveVideoErrorTitle'.tr,
          content: 'tryAgainMsg'.tr,
          actionText: 'Ok',
          actionColor: Colors.red,
          action: () => Get.offAllNamed(Routes.HOME),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool _pressedSave = false;

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45,
      height: MediaQuery.of(context).size.height * 0.1,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 5.0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(80.0)),
          primary: Colors.green,
        ),
        child: Text(
          'save'.tr,
          style: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.of(context).size.width * 0.06,
          ),
        ),
        onPressed: () {
          // Prevents user from clicking it twice
          if (!_pressedSave) {
            _pressedSave = true;
            _saveVideo(context);
          }
        },
      ),
    );
  }
}
