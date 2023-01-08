import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:group_radio_button/group_radio_button.dart';
// import 'package:video_player/video_player.dart';
import 'package:video_trimmer/video_trimmer.dart';

import '../../controllers/recording_settings_controller.dart';
import '../../routes/app_pages.dart';
import '../../utils/constants.dart';
import '../../utils/custom_checkbox_list_tile.dart';
import '../../utils/custom_dialog.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/storage_utils.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import 'widgets/save_button.dart';

class SaveVideoPage extends StatefulWidget {
  @override
  _SaveVideoPageState createState() => _SaveVideoPageState();
}

class _SaveVideoPageState extends State<SaveVideoPage> {
  final Map<String, dynamic> routeArguments = Get.arguments;
  final RecordingSettingsController _recordingSettingsController = Get.find();

  late String _tempVideoPath;
  final Trimmer _trimmer = Trimmer();

  final TextEditingController customLocationTextController =
      TextEditingController();

  late Color pickerColor;
  late Color currentColor;

  final double textOutlineStrokeWidth = 1;

  late String _dateFormatValue;

  late String _dateWrittenValue;

  List<String> _dateFormats = [
    DateFormatUtils.getToday(
      allowCheckFormattingDayFirst: true,
    ),
    DateFormatUtils.getWrittenToday(lang: Get.locale!.languageCode),
  ];

  late bool isTextDate;

  String? _currentAddress;
  Position? _currentPosition;
  bool isGeotaggingEnabled = false;
  String? _subtitles;
  double _videoStartValue = 0.0;
  double _videoEndValue = 0.0;
  bool _isVideoPlaying = false;
  bool _isLocationProcessing = false;

  void _initCorrectDates() {
    final DateTime _determinedDate = routeArguments['currentDate'];

    final String _dateCommonValue = DateFormatUtils.getDate(
      _determinedDate,
      allowCheckFormattingDayFirst: true,
    );

    _dateWrittenValue = DateFormatUtils.getWrittenToday(
      customDate: _determinedDate,
      lang: Get.locale!.languageCode,
    );

    _recordingSettingsController.dateFormat.value == 0
        ? _dateFormatValue = _dateCommonValue
        : _dateFormatValue = _dateWrittenValue;

    _dateFormats = [
      _dateCommonValue,
      _dateWrittenValue,
    ];
  }

  Color parseColorString(String colorString) {
    if (colorString.isEmpty) {
      return Colors.white;
    }
    final List<String> colorStringList = colorString.split(',');
    try {
      return Color.fromARGB(
        int.parse(colorStringList[3]),
        int.parse(colorStringList[0]),
        int.parse(colorStringList[1]),
        int.parse(colorStringList[2]),
      );
    } catch (e) {
      Utils.logError(e);
      return Colors.white;
    }
  }

  void toggleGeotaggingStatus() {
    setState(() {
      isGeotaggingEnabled = !isGeotaggingEnabled;
    });
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      toggleGeotaggingStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'locationServicesDisabled'.tr,
          ),
        ),
      );
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'locationPermissionDenied'.tr,
            ),
          ),
        );
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'locationPermissionPermanentlyDenied'.tr,
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;
    setState(() {
      _isLocationProcessing = true;
    });
    await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 20),
    ).then((Position position) async {
      setState(() => _currentPosition = position);
      await _getAddressFromLatLng(_currentPosition!);
    }).catchError((e) {
      Utils.logError('[Geolocation] - Failed to get location: $e');
      if (isGeotaggingEnabled) {
        toggleGeotaggingStatus();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'locationServiceError'.tr,
          ),
        ),
      );
    });

    setState(() {
      _isLocationProcessing = false;
    });
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    await placemarkFromCoordinates(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      localeIdentifier: Get.locale!.languageCode,
    ).then((List<Placemark> placemarks) {
      final Placemark place = placemarks[0];
      String city = '';
      if (place.locality?.isNotEmpty == true) {
        city = place.locality!;
      } else if (place.subAdministrativeArea?.isNotEmpty == true) {
        city = place.subAdministrativeArea!;
      } else if (place.administrativeArea?.isNotEmpty == true) {
        city = place.administrativeArea!;
      }
      setState(() {
        _currentAddress = '$city, ${place.country}';
      });

      Utils.logError('[Geolocation] - Location obtained successfully!');
    }).catchError((e) {
      Utils.logError('[Geolocation] - Failed to decode location: $e');
      if (isGeotaggingEnabled) {
        toggleGeotaggingStatus();
      }
      setState(() {
        _isLocationProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'locationServiceError'.tr,
          ),
        ),
      );
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
              final r = pickerColor.red;
              final g = pickerColor.green;
              final b = pickerColor.blue;
              final a = pickerColor.alpha;
              final colorString = '$r,$g,$b,$a';
              _recordingSettingsController.setDateColor(colorString);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    pickerColor =
        parseColorString(_recordingSettingsController.dateColor.value);
    currentColor = pickerColor;
    _tempVideoPath = routeArguments['videoPath'];
    isTextDate = _recordingSettingsController.dateFormat.value == 1;
    _initCorrectDates();
    _initVideoPlayerController();
    super.initState();
  }

  @override
  void dispose() {
    _trimmer.videoPlayerController?.dispose();
    super.dispose();
  }

  void _initVideoPlayerController() {
    _trimmer
        .loadVideo(
      videoFile: File(routeArguments['videoPath']),
    )
        .then((_) {
      _trimmer.videoPlayerController?.setLooping(true);
      // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
      setState(() {});
    });
  }

  void videoPlay() async {
    final bool playbackState = await _trimmer.videoPlaybackControl(
      startValue: _videoStartValue,
      endValue: _videoEndValue,
    );
    setState(() {
      _isVideoPlaying = playbackState;
    });
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
            VideoViewer(
              trimmer: _trimmer,
            ),
            Center(
              child: Opacity(
                opacity: _isVideoPlaying ? 0.0 : 1.0,
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
                      isTextDate ? _dateWrittenValue : _dateFormatValue,
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.03,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = textOutlineStrokeWidth
                          ..color = invert(currentColor),
                      ),
                    ),
                    Text(
                      isTextDate ? _dateWrittenValue : _dateFormatValue,
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
    return WillPopScope(
      onWillPop: () async {
        // Prevent showing the option to re-record video if not coming from the recording page
        final isFromRecordingPage = routeArguments['isFromRecordingPage'];
        if (!isFromRecordingPage) {
          // Deleting video from cache
          StorageUtils.deleteFile(_tempVideoPath);
          Get.back();
        } else {
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
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('saveVideo'.tr),
        ),
        floatingActionButton: Visibility(
          visible: !_isLocationProcessing,
          replacement: const FloatingActionButton(
            onPressed: null,
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
            backgroundColor: AppColors.green,
          ),
          child: SaveButton(
            videoPath: _tempVideoPath,
            videoController: _trimmer.videoPlayerController!,
            dateColor: currentColor,
            dateFormat: _dateFormatValue,
            isTextDate: isTextDate,
            userLocation: customLocationTextController.text.isEmpty
                ? _currentAddress ?? ''
                : customLocationTextController.text,
            subtitles: _subtitles,
            videoStartInMilliseconds: _videoStartValue,
            videoEndInMilliseconds: _videoEndValue,
            videoDuration:
                _trimmer.videoPlayerController!.value.duration.inSeconds,
            isGeotaggingEnabled: isGeotaggingEnabled,
            textOutlineColor: invert(currentColor),
            textOutlineWidth: textOutlineStrokeWidth,
            determinedDate: routeArguments['currentDate'],
          ),
        ),
        body: SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Column(
              children: [
                _dailyVideoPlayer(),
                const SizedBox(height: 8),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: TrimViewer(
                      trimmer: _trimmer,
                      viewerHeight: 50.0,
                      type: ViewerType.fixed,
                      editorProperties: TrimEditorProperties(
                        borderWidth: 4.0,
                        circleSize: 6.0,
                        circleSizeOnDrag: 9.0,
                        sideTapSize: 21,
                        circlePaintColor: ThemeService().isDarkTheme()
                            ? Colors.white
                            : Colors.black,
                        borderPaintColor: ThemeService().isDarkTheme()
                            ? Colors.white
                            : Colors.black,
                      ),
                      durationStyle: DurationStyle.FORMAT_MM_SS,
                      durationTextStyle: ThemeService().isDarkTheme()
                          ? const TextStyle(color: Colors.white)
                          : const TextStyle(color: Colors.black),
                      maxVideoLength: const Duration(seconds: 10),
                      viewerWidth: MediaQuery.of(context).size.width,
                      onChangeStart: (value) => _videoStartValue = value,
                      onChangeEnd: (value) => _videoEndValue = value,
                      onChangePlaybackState: (value) =>
                          setState(() => _isVideoPlaying = value),
                    ),
                  ),
                ),
                Expanded(child: videoProperties()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget videoProperties() {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          Center(
            child: Text(
              'editVideoProperties'.tr,
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.height * 0.019,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),

          // Date color
          Stack(
            children: [
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.03,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.mainColor,
                  ),
                ),
                child: GestureDetector(
                  onTap: () => colorPickerDialog(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                left: MediaQuery.of(context).size.height * 0.02,
                                bottom:
                                    MediaQuery.of(context).size.height * 0.02,
                              ),
                              child: Text(
                                'dateColorAndFormat'.tr,
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.height *
                                      0.019,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: currentColor,
                              ),
                              width: MediaQuery.of(context).size.width * 0.09,
                              height: MediaQuery.of(context).size.width * 0.09,
                              child: Icon(
                                Icons.edit,
                                color: invert(currentColor),
                              ),
                            ),
                            const SizedBox(height: 5.0),
                          ],
                        ),
                      ),
                      Expanded(
                        child: RadioGroup<String>.builder(
                          direction: Axis.vertical,
                          horizontalAlignment: MainAxisAlignment.start,
                          groupValue:
                              _recordingSettingsController.dateFormat.value == 0
                                  ? _dateFormatValue
                                  : _dateWrittenValue,
                          fillColor: AppColors.yellow,
                          onChanged: (value) => setState(() {
                            _dateFormatValue = value!;
                            // Place date in the bottom if it is text format
                            _dateFormatValue == _dateFormats[0]
                                ? isTextDate = false
                                : isTextDate = true;

                            // Save the date format in shared preferences
                            _recordingSettingsController.setDateFormat(
                                _dateFormatValue == _dateFormats[0] ? 0 : 1);
                          }),
                          items: _dateFormats,
                          itemBuilder: (item) => RadioButtonBuilder(
                            item,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 3,
                left: 3,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.mainColor,
                  ),
                  child: const Center(
                    child: Text('1'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),

          // Geotagging
          Stack(
            children: [
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.03,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.purple,
                  ),
                ),
                child: Column(
                  children: [
                    CustomCheckboxListTile(
                      isChecked: isGeotaggingEnabled,
                      onChanged: (_) async {
                        toggleGeotaggingStatus();
                        if (isGeotaggingEnabled) {
                          Utils.logInfo('[Geolocation] - Getting location...');
                          await _getCurrentPosition();
                        }
                        setState(() {});
                      },
                      padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.04),
                      title: Text(
                        'enableGeotagging'.tr,
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.height * 0.019,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.04),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: () async {
                                await showCustomLocationDialog();
                              },
                              child: Text(
                                'setCustomLocation'.tr,
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.height *
                                      0.019,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              await showCustomLocationDialog();
                            },
                            icon: const Icon(Icons.edit_location_alt),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5.0),
                  ],
                ),
              ),
              Positioned(
                top: 3,
                left: 3,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.purple,
                  ),
                  child: const Center(
                    child: Text('2'),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10.0),

          // Subtitles
          Stack(
            children: [
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.03,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.yellow,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10.0),
                      Text(
                        'subtitles'.tr,
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.height * 0.019,
                        ),
                      ),
                      TextField(
                        cursorColor: Colors.green,
                        maxLines: null,
                        onChanged: (value) => setState(() {
                          _subtitles = value;
                        }),
                        decoration: InputDecoration(
                          hintText: 'enterSubtitles'.tr,
                          filled: true,
                          border: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.transparent),
                          ),
                          enabledBorder: InputBorder.none,
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.transparent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10.0),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 3,
                left: 3,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.yellow,
                  ),
                  child: const Center(
                    child: Text('3'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> showCustomLocationDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Center(
          child: Text(
            'setCustomLocation'.tr.split('(').first,
          ),
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
            onPressed: () async {
              if (!isGeotaggingEnabled &&
                  customLocationTextController.text.isNotEmpty) {
                toggleGeotaggingStatus();
              }
              Navigator.pop(context);
            },
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
  }
}
