import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/controllers/daily_entry_controller.dart';
import 'package:one_second_diary/controllers/video_count_controller.dart';
import 'package:one_second_diary/routes/app_pages.dart';
import 'package:one_second_diary/utils/constants.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';
import 'package:one_second_diary/utils/utils.dart';
import 'package:tapioca/tapioca.dart';

class SaveButton extends StatelessWidget {
  SaveButton({this.videoPath});

  // Finding controllers
  final DailyEntryController dayController = Get.find();
  final VideoCountController videoCountController = Get.find();

  // Video path from cache
  final String videoPath;

  // Properties to edit the video with current date
  // TODO: Get locale based on language selected
  final String today =
      Utils.getToday(isBr: Get.deviceLocale.countryCode == 'BR');
  final int x = 1660;
  final int y = 20;
  final int size = 40;
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
            today,
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

          dayController.updateDaily();

          // Updates the controller: videoCount += 1
          if (!isEdit) {
            videoCountController.updateVideoCount();
          }

          // Showing confirmation popup
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Video saved!'),
              actions: <Widget>[
                RaisedButton(
                  color: Colors.green,
                  child: Text('Ok'),
                  onPressed: () => Get.offAllNamed(Routes.HOME),
                ),
              ],
            ),
          );
        },
      );

      // Utils().logInfo('Video saved!');
    } catch (e) {
      // Utils().logError('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // To prevent user of pressing it twice
    bool _pressedSave = false;

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45,
      height: MediaQuery.of(context).size.height * 0.1,
      child: RaisedButton(
        elevation: 5.0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(80.0)),
        color: Colors.green,
        child: Text(
          'Save',
          style: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.of(context).size.width * 0.06,
          ),
        ),
        onPressed: () {
          // Prevents the user of clicking it twice
          if (!_pressedSave) {
            _pressedSave = true;
            _saveVideo(context);
          }
        },
      ),
    );
  }
}
