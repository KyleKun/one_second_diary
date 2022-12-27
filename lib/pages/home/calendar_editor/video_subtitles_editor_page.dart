import 'dart:io';

import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../../utils/ffmpeg_api_wrapper.dart';
import '../../../utils/storage_utils.dart';
import '../../../utils/utils.dart';

class VideoSubtitlesEditorPage extends StatefulWidget {
  const VideoSubtitlesEditorPage({
    super.key,
    required this.videoPath,
    required this.subtitles,
  });

  final String videoPath;
  final String? subtitles;

  @override
  State<VideoSubtitlesEditorPage> createState() =>
      _VideoSubtitlesEditorPageState();
}

class _VideoSubtitlesEditorPageState extends State<VideoSubtitlesEditorPage> {
  double _opacity = 1.0;
  String _subtitles = '';
  bool isProcessing = false;
  bool isEdit = false;
  late VideoPlayerController _videoController;
  final TextEditingController subtitlesController = TextEditingController();

  @override
  void initState() {
    _initVideoPlayerController();
    if (widget.subtitles != null) {
      _subtitles = widget.subtitles!
          .trim()
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(r'\s+'), ' ');
      subtitlesController.text = _subtitles;
      print(_subtitles);
      isEdit = true;
    }

    super.initState();
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  void _initVideoPlayerController() {
    _videoController = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        _videoController.setLooping(true);
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('subtitles'.tr),
      ),
      resizeToAvoidBottomInset: false,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              GestureDetector(
                onTap: () => videoPlay(),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      VideoPlayer(_videoController),
                      Center(
                        child: Opacity(
                          opacity: _opacity,
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.25,
                            height: MediaQuery.of(context).size.width * 0.25,
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_arrow,
                                size: 72.0,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: subtitlesController,
                  cursorColor: Colors.green,
                  maxLines: null,
                  onChanged: (value) => setState(() {
                    _subtitles = value;
                  }),
                  decoration: InputDecoration(
                    hintText: 'enterSubtitles'.tr,
                    filled: true,
                    border: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.45,
              height: MediaQuery.of(context).size.height * 0.08,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 5.0,
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(80.0),
                  ),
                ),
                onPressed: () async {
                  setState(() {
                    isProcessing = true;
                  });
                  print('running');
                  final subtitles = await Utils.writeSrt(
                    _subtitles,
                    _videoController.value.duration.inSeconds,
                  );

                  String command = '';
                  final String tempPath =
                      '${widget.videoPath.split('.mp4').first}_temp.mp4';

                  if (isEdit) {
                    debugPrint('editing subtitles');
                    command =
                        '-i ${widget.videoPath} -i $subtitles -c:s mov_text -c:v copy -c:a copy -map 0:v -map 0:a? -map 1 -disposition:s:0 default $tempPath -y';
                  } else {
                    debugPrint('adding new subtitles');
                    command =
                        '-i ${widget.videoPath} -i $subtitles -c copy -c:s mov_text $tempPath -y';
                  }

                  await executeFFmpeg(command).then((session) async {
                    print(session.getCommand().toString());
                    final returnCode = await session.getReturnCode();
                    if (ReturnCode.isSuccess(returnCode)) {
                      print('Video edited successfully');
                      StorageUtils.deleteFile(widget.videoPath);
                      StorageUtils.renameFile(tempPath, widget.videoPath);
                    } else {
                      print('Video editing failed');
                      final sessionLog = await session.getAllLogsAsString();
                      final failureStackTrace =
                          await session.getFailStackTrace();
                      debugPrint(
                          'Session lasted for ${await session.getDuration()} ms');
                      debugPrint(session.getArguments().toString());
                      debugPrint('Session log is $sessionLog');
                      debugPrint('Failure stacktrace - $failureStackTrace');
                    }
                  });

                  setState(() {
                    isProcessing = false;
                  });
                  Get.back();
                },
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
              ),
            ),
          ),
        ],
      ),
    );
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
}
