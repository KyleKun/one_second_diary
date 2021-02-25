import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/pages/save_video/widgets/save_button.dart';
import 'package:one_second_diary/routes/app_pages.dart';
import 'package:video_player/video_player.dart';

class SaveVideoPage extends StatefulWidget {
  @override
  _SaveVideoPageState createState() => _SaveVideoPageState();
}

class _SaveVideoPageState extends State<SaveVideoPage> {
  String _tempVideoPath;
  double _opacity = 1.0;
  var _videoController;

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

  Widget _dailyVideoPlayer() {
    return GestureDetector(
      onTap: () => videoPlay(),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            VideoPlayer(_videoController),
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
    );
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
                ? _dailyVideoPlayer()
                : Center(child: CircularProgressIndicator()),
            Spacer(),
            SaveButton(videoPath: _tempVideoPath),
            Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
