import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/utils/constants.dart';
import 'package:one_second_diary/utils/ffmpeg_api_wrapper.dart';
import 'package:one_second_diary/utils/utils.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';

class CreateMovieButton extends StatelessWidget {
  void _createMovie() async {
    final allVideos = Utils.getAllVideosFromStorage();
    Utils().logInfo('Creating movie with the following files: $allVideos');

    // Creating txt that will be used with ffmpeg
    String txtPath = await Utils.writeTxt(allVideos);
    String today = Utils.getToday();
    String outputPath =
        StorageUtil.getString('appPath') + 'OneSecondDiary-Movie-$today.mp4';

    await executeFFmpeg(
        '-f concat -safe 0 -i $txtPath -map 0 -c copy $outputPath');
    Utils().logInfo('Cache video saved at: $outputPath');

    GallerySaver.saveVideo(outputPath, albumName: 'OSD-Movies').then((_) {
      Utils.deleteFile(outputPath);
      Utils().logInfo('Video saved in gallery in the folder OSD-Movies!');
      showDialog(
        context: Get.context,
        builder: (context) => AlertDialog(
          title: Text('Video saved in gallery in OSD-Movies folder!'),
          actions: <Widget>[
            RaisedButton(
              color: AppColors.green,
              child: Text('Ok'),
              onPressed: () => Get.back(),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      height: MediaQuery.of(context).size.width * 0.15,
      child: RaisedButton(
        elevation: 5.0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(80.0)),
        color: AppColors.mainColor,
        onPressed: () {
          // TODO: prevent double click
          _createMovie();
        },
        child: Text(
          'Create',
          style: TextStyle(color: Colors.white, fontSize: 22.0),
        ),
      ),
    );
  }
}
