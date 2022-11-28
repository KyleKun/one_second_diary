import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:get/get.dart';
import 'package:group_radio_button/group_radio_button.dart';
import 'package:video_player/video_player.dart';

import '../../routes/app_pages.dart';
import '../../utils/constants.dart';
import '../../utils/custom_dialog.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/storage_utils.dart';
import 'widgets/save_button.dart';

class SaveVideoPage extends StatefulWidget {
  @override
  _SaveVideoPageState createState() => _SaveVideoPageState();
}

class _SaveVideoPageState extends State<SaveVideoPage> {
  double _opacity = 1.0;
  late String _tempVideoPath;
  late var _videoController;

  Color pickerColor = const Color(0xff000000);
  Color currentColor = const Color(0xff000000);

  String _dateFormatValue =
      DateFormatUtils.getToday(isDayFirst: DateFormatUtils.isDayFirstPattern());

  final List<String> _dateFormats = [
    DateFormatUtils.getToday(isDayFirst: DateFormatUtils.isDayFirstPattern()),
    DateFormatUtils.getWrittenToday(lang: Get.locale!.languageCode),
  ];

  bool isTextDate = false;

  void changeColor(Color color) {
    setState(() => pickerColor = color);
  }

  Future colorPickerDialog() {
    return showDialog(
      barrierDismissible: false,
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: Text('selectColor'.tr),
        content: ColorPicker(
          pickerColor: pickerColor,
          onColorChanged: changeColor,
          portraitOnly: true,
        ),
        actions: <Widget>[
          TextButton(
            child: Text(
              'done'.tr,
              style: const TextStyle(
                color: AppColors.green,
              ),
            ),
            onPressed: () {
              setState(() => currentColor = pickerColor);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

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

  void closePopupAndPushToRecording(String cacheVideoPath) {
    // Deleting video from cache
    StorageUtils.deleteFile(cacheVideoPath);
    Get.back();
    Get.offNamed(Routes.RECORDING);
  }

  Color invert(Color color) {
    final r = 255 - color.red;
    final g = 255 - color.green;
    final b = 255 - color.blue;

    return Color.fromARGB((color.opacity * 255).round(), r, g, b);
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
            Align(
              alignment: isTextDate ? Alignment.bottomLeft : Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Stack(
                  children: <Widget>[
                    Text(
                      _dateFormatValue,
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.03,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 2
                          ..color = invert(currentColor),
                      ),
                    ),
                    Text(
                      _dateFormatValue,
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.03,
                        color: currentColor,
                      ),
                    ),
                  ],
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
    // Utils().logInfo(Get.locale!.languageCode);
    return WillPopScope(
      onWillPop: () async {
        showDialog(
          barrierDismissible: false,
          context: Get.context!,
          builder: (context) => CustomDialog(
            isDoubleAction: true,
            title: 'discardVideoTitle'.tr,
            content: 'discardVideoDesc'.tr,
            actionText: 'yes'.tr,
            actionColor: Colors.green,
            action: () => closePopupAndPushToRecording(_tempVideoPath),
            action2Text: 'no'.tr,
            action2Color: Colors.red,
            action2: () => Get.back(),
          ),
        );
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('saveVideo'.tr),
        ),
        body: Column(
          children: [
            _dailyVideoPlayer(),
            const Spacer(),
            videoProperties(),
            const Spacer(flex: 2),
            SaveButton(
              videoPath: _tempVideoPath,
              videoController: _videoController,
              dateColor: currentColor,
              dateFormat: _dateFormatValue,
              isTextDate: isTextDate,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget videoProperties() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.mainColor),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Center(
            child: Text(
              'editVideoProperties'.tr,
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.height * 0.025,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.width * 0.6,
            // decoration: BoxDecoration(
            //   border: Border.all(color: AppColors.mainColor),
            //   borderRadius: BorderRadius.circular(30),
            // ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => colorPickerDialog(),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                            left: MediaQuery.of(context).size.width * 0.04),
                        child: Text(
                          'dateColor'.tr,
                          style: TextStyle(
                            fontSize:
                                MediaQuery.of(context).size.height * 0.025,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                            left: MediaQuery.of(context).size.width * 0.04),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: currentColor,
                          ),
                          width: MediaQuery.of(context).size.width * 0.08,
                          height: MediaQuery.of(context).size.width * 0.08,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        left: MediaQuery.of(context).size.width * 0.04,
                      ),
                      child: Text(
                        'dateFormat'.tr,
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.height * 0.025,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(
                        MediaQuery.of(context).size.height * 0.01,
                      ),
                      child: RadioGroup<String>.builder(
                        direction: Axis.vertical,
                        horizontalAlignment: MainAxisAlignment.start,
                        groupValue: _dateFormatValue,
                        onChanged: (value) => setState(() {
                          _dateFormatValue = value!;
                          // Place date in the bottom if it is text format
                          _dateFormatValue == _dateFormats[0]
                              ? isTextDate = false
                              : isTextDate = true;
                        }),
                        items: _dateFormats,
                        itemBuilder: (item) => RadioButtonBuilder(
                          item,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
