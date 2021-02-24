import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/controllers/daily_entry_controller.dart';
import 'package:one_second_diary/controllers/video_count_controller.dart';
import 'package:one_second_diary/routes/app_pages.dart';
import 'package:one_second_diary/utils/utils.dart';

class SaveButton extends StatelessWidget {
  final DailyEntryController dayController = Get.find();
  final VideoCountController videoCountController = Get.find();

  void _saveVideo(BuildContext context) {
    dayController.updateDaily();
    videoCountController.updateVideoCount();

    Utils().logInfo('Video saved!');

    //! Better to check if folder is created again
    //TODO place date at the top with tapioca and save video on storage
    //
    //

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Video saved!'),
        actions: <Widget>[
          RaisedButton(
            child: Text('Ok'),
            onPressed: () => Get.offAllNamed(Routes.HOME),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45,
      height: MediaQuery.of(context).size.width * 0.18,
      child: RaisedButton(
        color: Colors.green,
        child: Text(
          'Save',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22.0,
          ),
        ),
        onPressed: () {
          _saveVideo(context);
        },
      ),
    );
  }
}
