import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/controllers/day_controller.dart';
import 'package:one_second_diary/routes/app_pages.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:video_player/video_player.dart';

class SaveVideoPage extends StatefulWidget {
  @override
  _SaveVideoPageState createState() => _SaveVideoPageState();
}

class _SaveVideoPageState extends State<SaveVideoPage> {
  String _tempVideoPath;
  double _opacity = 1.0;
  var _videoController;

  final DayController dayController = Get.find();

  @override
  void initState() {
    _tempVideoPath = Get.arguments;
    _initVideoPlayerController();
    super.initState();
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  void _initVideoPlayerController() {
    _videoController = VideoPlayerController.file(File(_tempVideoPath))
      ..initialize().then((_) {
        _videoController.setLooping(true);
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });
  }

  Widget viewer() {
    return VideoPlayer(_videoController);
  }

  void videoPlay() async {
    if (!_videoController.value.isPlaying) {
      await _videoController.play();
      setState(() {
        _opacity = 0.0;
      });
    } else {
      await _videoController.pause();
      setState(() {
        _opacity = 1.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Discard this video?'),
            actions: <Widget>[
              RaisedButton(
                child: Text('Yes'),
                onPressed: () => Get.offNamed(Routes.RECORDING),
              ),
              RaisedButton(child: Text('No'), onPressed: () => Get.back()),
            ],
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Save video"),
        ),
        body: Column(
          children: [
            _videoController.value.initialized
                ? GestureDetector(
                    onTap: () => videoPlay(),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        children: [
                          viewer(),
                          Center(
                            child: Opacity(
                              opacity: _opacity,
                              child: Icon(
                                Icons.play_arrow,
                                size: 56.0,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Center(child: CircularProgressIndicator()),
            SizedBox(
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
                  StorageUtil.putBool('dailyEntry', true);
                  dayController.updateDaily();

                  new Alert(
                    context: context,
                    type: AlertType.success,
                    title: "Saved Successfully",
                    desc: "Yay, your daily entry was saved!",
                    style: AlertStyle(
                      animationType: AnimationType.fromTop,
                      isOverlayTapDismiss: false,
                      overlayColor: Colors.black26,
                      backgroundColor: Colors.grey[100],
                    ),
                    buttons: [
                      DialogButton(
                        radius: BorderRadius.circular(90),
                        color: Colors.green,
                        child: Text('Ok'),
                        width: 60,
                        onPressed: () {
                          Get.offAllNamed(Routes.HOME);
                        },
                      ),
                    ],
                  ).show();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
