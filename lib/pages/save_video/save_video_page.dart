import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:group_radio_button/group_radio_button.dart';
import 'package:video_player/video_player.dart';

import '../../routes/app_pages.dart';
import '../../utils/constants.dart';
import '../../utils/custom_checkbox_list_tile.dart';
import '../../utils/custom_dialog.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/shared_preferences_util.dart';
import '../../utils/storage_utils.dart';
import 'widgets/save_button.dart';

class SaveVideoPage extends StatefulWidget {
  @override
  _SaveVideoPageState createState() => _SaveVideoPageState();
}

class _SaveVideoPageState extends State<SaveVideoPage> {
  double _opacity = 1.0;
  late String _tempVideoPath;
  late VideoPlayerController _videoController;

  final TextEditingController customLocationTextController =
      TextEditingController();

  Color pickerColor = const Color(0xff000000);
  Color currentColor = const Color(0xff000000);

  final double textOutlineStrokeWidth = 1;

  String _dateFormatValue = DateFormatUtils.getToday(
    allowCheckFormattingDayFirst: true,
  );

  final List<String> _dateFormats = [
    DateFormatUtils.getToday(
      allowCheckFormattingDayFirst: true,
    ),
    DateFormatUtils.getWrittenToday(lang: Get.locale!.languageCode),
  ];

  bool isTextDate = false;

  String? _currentAddress;
  Position? _currentPosition;
  bool isGeotaggingEnabled =
      SharedPrefsUtil.getBool('isGeotaggingEnabled') ?? false;
  String? _subtitles;

  Future<void> checkGeotaggingStatus() async {
    isGeotaggingEnabled =
        SharedPrefsUtil.getBool('isGeotaggingEnabled') ?? false;
    if (isGeotaggingEnabled) {
      await _getCurrentPosition();
    }
  }

  Future<void> toggleGeotaggingStatus() async {
    isGeotaggingEnabled = !isGeotaggingEnabled;
    await SharedPrefsUtil.putBool('isGeotaggingEnabled', isGeotaggingEnabled);
    setState(() {});
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location services are disabled. Please enable the services')));
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')));
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location permissions are permanently denied, we cannot request permissions.')));
      return false;
    }
    return true;
  }

  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();

    if (!hasPermission) return;
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((Position position) {
      setState(() => _currentPosition = position);
      _getAddressFromLatLng(_currentPosition!);
    }).catchError((e) {
      debugPrint(e);
    });
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    await placemarkFromCoordinates(
            _currentPosition!.latitude, _currentPosition!.longitude)
        .then((List<Placemark> placemarks) {
      final Placemark place = placemarks[0];
      String city = '';
      if (place.locality != null && place.locality?.isNotEmpty == true) {
        city = place.locality!;
      } else if (place.subAdministrativeArea != null &&
          place.subAdministrativeArea?.isNotEmpty == true) {
        city = place.subAdministrativeArea!;
      } else if (place.administrativeArea != null &&
          place.administrativeArea?.isNotEmpty == true) {
        city = place.administrativeArea!;
      }
      setState(() {
        _currentAddress = '$city, ${place.country}';
      });
    }).catchError((e) {
      debugPrint(e);
    });
  }

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
    checkGeotaggingStatus().whenComplete(
      () {
        debugPrint(_currentAddress);
        setState(() {});
      },
    );
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
                padding: const EdgeInsets.all(10.0),
                child: Stack(
                  children: [
                    Text(
                      _dateFormatValue,
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.03,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = textOutlineStrokeWidth
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
            Visibility(
              visible: isGeotaggingEnabled,
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Stack(
                    children: [
                      Text(
                        customLocationTextController.text.isEmpty
                            ? _currentAddress ??
                                customLocationTextController.text
                            : customLocationTextController.text,
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.032,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = textOutlineStrokeWidth
                            ..color = invert(currentColor),
                        ),
                      ),
                      Text(
                        customLocationTextController.text.isEmpty
                            ? _currentAddress ??
                                customLocationTextController.text
                            : customLocationTextController.text,
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.032,
                          color: currentColor,
                        ),
                      ),
                    ],
                  ),
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
        floatingActionButton: SaveButton(
          videoPath: _tempVideoPath,
          videoController: _videoController,
          dateColor: currentColor,
          dateFormat: _dateFormatValue,
          isTextDate: isTextDate,
          userLocation: customLocationTextController.text.isEmpty
              ? _currentAddress ?? ''
              : customLocationTextController.text,
          subtitles: _subtitles,
          videoDuration: _videoController.value.duration.inSeconds,
          isGeotaggingEnabled: isGeotaggingEnabled,
          textOutlineColor: invert(currentColor),
          textOutlineWidth: textOutlineStrokeWidth,
        ),
        body: SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Column(
              children: [
                _dailyVideoPlayer(),
                Expanded(child: videoProperties()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget videoProperties() {
    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.02),
        Center(
          child: Text(
            'editVideoProperties'.tr,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.height * 0.020,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02),

        // Date color
        GestureDetector(
          onTap: () => colorPickerDialog(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: MediaQuery.of(context).size.width * 0.04,
                  bottom: MediaQuery.of(context).size.height * 0.02,
                ),
                child: Text(
                  'dateColor'.tr,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.height * 0.020,
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

        // Date Format
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
                  fontSize: MediaQuery.of(context).size.height * 0.020,
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

        // Geotagging
        CustomCheckboxListTile(
          isChecked: isGeotaggingEnabled,
          onChanged: (_) async {
            await toggleGeotaggingStatus();
            if (isGeotaggingEnabled) {
              debugPrint('Getting location');
              await _getCurrentPosition();
            }
            setState(() {});
          },
          padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.04),
          title: Text(
            'enableGeotagging'.tr,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.height * 0.020,
            ),
          ),
        ),

        ListTile(
          onTap: () async {
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Center(
                  child: Text('setCustomLocation'.tr),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: customLocationTextController,
                      cursorColor: Colors.green,
                      decoration: InputDecoration(
                        hintText: 'enterLocation'.tr,
                        filled: true,
                        border: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.green),
                        ),
                        enabledBorder: InputBorder.none,
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.green,
                    ),
                    child: Text('ok'.tr),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      customLocationTextController.clear();
                      setState(() {});
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: Text('reset'.tr),
                  )
                ],
              ),
            );
          },
          title: Text(
            'setCustomLocation'.tr,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.height * 0.020,
            ),
          ),
        ),

        // Subtitles
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
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
                enabledBorder: InputBorder.none,
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
