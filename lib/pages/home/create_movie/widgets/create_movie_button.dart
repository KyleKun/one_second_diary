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

    // Needs more than 1 video to create movie
    if (allVideos.length < 2) {
      showDialog(
        context: Get.context,
        builder: (context) => AlertDialog(
          title: Text('Movie was not created!'),
          content: Text(
            'You need to have 2 or more recorded videos in order to create a movie',
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(primary: Colors.green),
              child: Text('Ok'),
              onPressed: () => Get.back(),
            ),
          ],
        ),
      );
    } else {
      try {
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
            builder: (context) => AlertDialog(
              title: Text('Movie created!'),
              content: Text('Video saved in gallery in OSD-Movies folder!'),
              actions: <Widget>[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(primary: Colors.green),
                  child: Text('Ok'),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
          );
        });
      } catch (e) {
        Utils().logError('$e');
        showDialog(
          context: Get.context,
          builder: (context) => AlertDialog(
            title: Text('Error creating movie!'),
            actions: <Widget>[
              ElevatedButton(
                style: ElevatedButton.styleFrom(primary: Colors.red),
                child: Text('Ok'),
                onPressed: () => Get.back(),
              ),
            ],
          ),
        );
      }
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
          // TODO: prevent double click and show loading
          _createMovie();
        },
        child: Text(
          'Create',
          style: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.of(context).size.width * 0.05,
          ),
        ),
      ),
    );
  }
}
