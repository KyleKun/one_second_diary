import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tapioca/tapioca.dart';

import '../../../controllers/daily_entry_controller.dart';
import '../../../controllers/video_count_controller.dart';
import '../../../routes/app_pages.dart';
import '../../../utils/custom_dialog.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/shared_preferences_util.dart';
import '../../../utils/storage_utils.dart';
// import '../../../utils/utils.dart';

class SaveButton extends StatefulWidget {
  SaveButton({
    required this.videoPath,
    required this.videoController,
    required this.dateColor,
    required this.dateFormat,
    required this.isTextDate,
  });

  // Finding controllers
  final String videoPath;
  final videoController;
  final Color dateColor;
  final String dateFormat;
  final bool isTextDate;

  @override
  _SaveButtonState createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  bool isProcessing = false;

  final DailyEntryController _dayController = Get.find();

  final VideoCountController _videoCountController = Get.find();

  void _saveVideo(BuildContext context) async {
    setState(() {
      isProcessing = true;
    });
    // Used to not increment videoCount controller
    bool isEdit = false;

    // Position y to render date
    final int y = widget.isTextDate ? 660 : 20; // HiRes: 1000 : 20
    // Position x to render date
    final int x = widget.isTextDate ? 32 : 1120; // HiRes: 50 : 1690
    // Text size
    const int size = 25; // HiRes: 35

    try {
      // Utils().logInfo('Saving video...');

      // Creates the folder if it is not created yet
      StorageUtils.createFolder();

      // Setting editing properties
      final Cup cup = Cup(
        Content(widget.videoPath),
        [
          TapiocaBall.textOverlay(
            // Date in the proper format
            widget.dateFormat,
            x,
            y,
            size,
            widget.dateColor,
          ),
        ],
      );

      // Path to save the final video
      final String finalPath =
          '${SharedPrefsUtil.getString('appPath')}${DateFormatUtils.getToday()}.mp4';

      // Check if video already exists and delete it if so (Edit daily feature)
      if (StorageUtils.checkFileExists(finalPath)) {
        isEdit = true;
        // Utils().logWarning('File already exists!');
        StorageUtils.deleteFile(finalPath);
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
          StorageUtils.deleteFile(widget.videoPath);

          // Stop loading animation
          setState(() {
            isProcessing = false;
          });

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
      // Deleting video from cache
      StorageUtils.deleteFile(widget.videoPath);

      setState(() {
        isProcessing = false;
      });
      // Utils().logError('$e');
      // Showing error popup
      showDialog(
        barrierDismissible: false,
        context: Get.context!,
        builder: (context) => CustomDialog(
          isDoubleAction: false,
          title: 'saveVideoErrorTitle'.tr,
          content: '${'tryAgainMsg'.tr}\n\nError: ${e.toString()}',
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
      height: MediaQuery.of(context).size.height * 0.08,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 5.0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(80.0)),
          primary: Colors.green,
        ),
        child: !isProcessing
            ? Text(
                'save'.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: MediaQuery.of(context).size.width * 0.07,
                ),
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
            _saveVideo(context);
          }
        },
      ),
    );
  }
}
