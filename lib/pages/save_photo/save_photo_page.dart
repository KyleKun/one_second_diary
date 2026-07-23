import 'dart:io';

import 'package:flutter/material.dart' hide RadioGroup;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:group_radio_button/group_radio_button.dart';
import '../../controllers/recording_settings_controller.dart';
import '../../utils/constants.dart';
import '../../utils/custom_checkbox_list_tile.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/shared_preferences_util.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../home/profiles/profiles_page.dart';
import 'widgets/save_photo_button.dart';
import 'widgets/tab_item.dart';

class SavePhotoPage extends StatefulWidget {
  @override
  _SavePhotoPageState createState() => _SavePhotoPageState();
}

class _SavePhotoPageState extends State<SavePhotoPage> {
  final Map<String, dynamic> routeArguments = Get.arguments;
  final RecordingSettingsController _recordingSettingsController = Get.find();

  late String _tempPhotoPath;

  final TextEditingController customLocationTextController = TextEditingController();
  final TextEditingController subtitlesTextController = TextEditingController();

  late Color pickerColor;
  late Color currentColor;

  final double textOutlineStrokeWidth = 1;

  late String _dateFinalFormatValueForVideoEdit;

  late String _dateWrittenValueForVideoEdit;

  List<String> _dateFormatsForVideoEdit = [
    DateFormatUtils.getToday(
      allowCheckFormattingDayFirst: true,
    ),
    DateFormatUtils.getWrittenToday(lang: Get.locale!.languageCode),
  ];

  late bool isTextDate;

  String? _currentAddress;
  Position? _currentPosition;
  bool isGeotaggingEnabled = SharedPrefsUtil.getBool('enableGeotagging') ?? false;
  String? _subtitles;
  int photoDurationInSeconds = 1;
  bool _isLocationProcessing = false;

  late final bool isDarkTheme = ThemeService().isDarkTheme();
  String selectedProfileName = Utils.getCurrentProfile();

  void _initCorrectDates() {
    final DateTime selectedDate = routeArguments['currentDate'];

    final String dateCommonValue = DateFormatUtils.getDate(
      selectedDate,
      allowCheckFormattingDayFirst: true,
    );

    _dateWrittenValueForVideoEdit = DateFormatUtils.getWrittenToday(
      customDate: selectedDate,
      lang: Get.locale!.languageCode,
    );

    _recordingSettingsController.dateFormatId.value == 0
        ? _dateFinalFormatValueForVideoEdit = dateCommonValue
        : _dateFinalFormatValueForVideoEdit = _dateWrittenValueForVideoEdit;

    _dateFormatsForVideoEdit = [
      dateCommonValue,
      _dateWrittenValueForVideoEdit,
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

  Future<void> setGeotagging() async {
    Utils.logInfo('[Geolocation] - Getting location...');
    await _getCurrentPosition().then(
      (_) => SharedPrefsUtil.putBool(
        'enableGeotagging',
        isGeotaggingEnabled,
      ),
    );
  }

  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;
    setState(() {
      _isLocationProcessing = true;
    });
    await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      ),
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
    const int maxAttempts = 3;
    int attempts = 0;

    while (attempts < maxAttempts) {
      try {
        await setLocaleIdentifier(Get.locale!.languageCode);
        await placemarkFromCoordinates(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
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
          Utils.logInfo('[Geolocation] - Location obtained successfully!');
        });
        break;
      } catch (e) {
        attempts++;
        if (attempts == maxAttempts) {
          Utils.logError('Function failed after $maxAttempts attempts: $e');
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
        } else {
          Utils.logError('[Geolocation] - Failed to decode location (attempt $attempts): $e');
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
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
              final r = (pickerColor.r * 255.0).round().clamp(0, 255);
              final g = (pickerColor.g * 255.0).round().clamp(0, 255);
              final b = (pickerColor.b * 255.0).round().clamp(0, 255);
              final a = (pickerColor.a * 255.0).round().clamp(0, 255);
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
    pickerColor = parseColorString(_recordingSettingsController.dateColor.value);
    currentColor = pickerColor;
    _tempPhotoPath = routeArguments['photoPath'];
    isTextDate = _recordingSettingsController.dateFormatId.value == 1;
    _initCorrectDates();
    if (isGeotaggingEnabled) {
      setGeotagging();
    }
    super.initState();
  }

  @override
  void dispose() {
     customLocationTextController.dispose();
     subtitlesTextController.dispose();
    super.dispose();
  }



  Color invert(Color color) {
    final r = 255 - (color.r * 255.0).round().clamp(0, 255);
    final g = 255 - (color.g * 255.0).round().clamp(0, 255);
    final b = 255 - (color.b * 255.0).round().clamp(0, 255);

    return Color.fromARGB((color.a * 255.0).round().clamp(0, 255), r, g, b);
  }

  Widget _dailyPhotoViewer() {
    return ColoredBox(
      color: AppColors.dark,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            Image.file(
              File(routeArguments['photoPath']),
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),

            Align(
              alignment: isTextDate ? Alignment.bottomLeft : Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Stack(
                  children: [
                    Text(
                      isTextDate ? _dateFormatsForVideoEdit.last : _dateFormatsForVideoEdit.first,
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.03,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = textOutlineStrokeWidth
                          ..color = invert(currentColor),
                      ),
                    ),
                    Text(
                      isTextDate ? _dateFormatsForVideoEdit.last : _dateFormatsForVideoEdit.first,
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
                            ? _currentAddress ?? customLocationTextController.text
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
                            ? _currentAddress ?? customLocationTextController.text
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

  Widget _durationSelectionButtons() {
    final List<int> options = [1, 2, 3, 4, 5, 10];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'seconds'.tr,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.height * 0.018,
            ),
          ),
          const SizedBox(width: 8.0),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((sec) {
                final bool isSelected = photoDurationInSeconds == sec;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        photoDurationInSeconds = sec;
                      });
                    },
                    borderRadius: BorderRadius.circular(15.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.green
                            : (isDarkTheme ? AppColors.dark : Colors.grey[300]),
                        borderRadius: BorderRadius.circular(15.0),
                        border: Border.all(
                          color: isSelected ? AppColors.green : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '${sec}s',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDarkTheme ? Colors.white : Colors.black),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13.0,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: Text(
          'savePhoto'.tr,
          style: const TextStyle(color: Colors.white),
        ),
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
        child: SavePhotoButton(
          photoPath: _tempPhotoPath,
          photoDurationInSeconds: photoDurationInSeconds,
          dateColor: currentColor,
          dateFormat: _dateFinalFormatValueForVideoEdit,
          isTextDate: isTextDate,
          userPosition: _currentPosition,
          userLocation: customLocationTextController.text.isEmpty
              ? _currentAddress ?? ''
              : customLocationTextController.text,
          subtitles: _subtitles,
          isGeotaggingEnabled: isGeotaggingEnabled,
          textOutlineColor: invert(currentColor),
          textOutlineWidth: textOutlineStrokeWidth,
          determinedDate: routeArguments['currentDate'],
        ),
      ),
      body: Column(
        children: [
          ListView(
            physics: const ClampingScrollPhysics(),
            shrinkWrap: true,
            children: [
              _dailyPhotoViewer(),
              const SizedBox(height: 8),
              _durationSelectionButtons(),
            ],
          ),
          Expanded(
            child: videoProperties(),
          ),
        ],
      ),
    );
  }

  Widget generalTabContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22.0),
          child: Row(
            children: [
              Text(
                'currentProfile'.tr,
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.height * 0.019,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  selectedProfileName.isEmpty ? 'default'.tr : selectedProfileName,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.height * 0.019,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Flexible(
                child: TextButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                        AppColors.dark.withValues(alpha: isDarkTheme ? 1.0 : 0.55)),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                  ),
                  onPressed: () {
                    Get.to(const ProfilesPage())?.then(
                      (_) => setState(() {
                        selectedProfileName = Utils.getCurrentProfile();
                      }),
                    );
                  },
                  child: Text(
                    'change'.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: MediaQuery.of(context).size.height * 0.017,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Date color
        GestureDetector(
          onTap: () => colorPickerDialog(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 22.0, right: 11.0),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).size.height * 0.02,
                      ),
                      child: Text(
                        'dateColorAndFormat'.tr,
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.height * 0.019,
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
                  groupValue: _recordingSettingsController.dateFormatId.value == 0
                      ? _dateFormatsForVideoEdit.first
                      : _dateFormatsForVideoEdit.last,
                  fillColor: AppColors.yellow,
                  onChanged: (value) => setState(() {
                    _dateFinalFormatValueForVideoEdit = value!;
                    // Place date in the bottom if it is text format
                    _dateFinalFormatValueForVideoEdit == _dateFormatsForVideoEdit.first
                        ? isTextDate = false
                        : isTextDate = true;

                    // Save the date format in shared preferences
                    _recordingSettingsController.setDateFormat(
                        _dateFinalFormatValueForVideoEdit == _dateFormatsForVideoEdit.first
                            ? 0
                            : 1);
                  }),
                  items: _dateFormatsForVideoEdit,
                  itemBuilder: (item) => RadioButtonBuilder(
                    item,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ],
    );
  }

  Widget locationTabContent() {
    return Column(
      children: [
        const SizedBox(height: 8),

        // Geotagging
        Container(
          margin: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.03,
          ),
          child: Column(
            children: [
              CustomCheckboxListTile(
                isChecked: isGeotaggingEnabled,
                onChanged: (_) async {
                  if (!_isLocationProcessing) {
                    toggleGeotaggingStatus();
                    if (isGeotaggingEnabled) {
                      await setGeotagging();
                    }
                    setState(() {});
                  }
                },
                padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.04),
                title: Text(
                  'enableGeotagging'.tr,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.height * 0.019,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.04),
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
                            fontSize: MediaQuery.of(context).size.height * 0.019,
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
      ],
    );
  }

  Widget subtitlesTabContent() {
    return Column(
      children: [
        const SizedBox(height: 8),

        // Subtitles
        Container(
          margin: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.03,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.04,
            ),
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
                const SizedBox(height: 4),
                TextField(
                  controller: subtitlesTextController,
                  style: TextStyle(
                    fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                    color: Colors.white,
                  ),
                  maxLines: 6,
                  readOnly: true,
                  onTap: () async => await showSubtitlesDialog(),
                  decoration: InputDecoration(
                    fillColor: AppColors.dark,
                    hintText: 'enterSubtitles'.tr,
                    hintStyle: const TextStyle(
                      color: Colors.white,
                    ),
                    filled: true,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDarkTheme ? Colors.white : Colors.black),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDarkTheme ? Colors.white : Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 10.0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget videoProperties() {
    return DefaultTabController(
      initialIndex: 0,
      length: 3,
      child: Column(
        children: [
          SizedBox(
            height: 42,
            child: TabBar(
              labelPadding: const EdgeInsets.all(10),
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(
                  color: ThemeService().isDarkTheme() ? Colors.white : Colors.black,
                  width: 4,
                ), // Indicator height
                // insets: EdgeInsets.only(left: 60, right: 40), // Indicator width
              ),
              isScrollable: true,
              tabs: [
                TabItem(
                  id: '1',
                  title: 'saveVideoTabOne'.tr,
                  color: AppColors.mainColor,
                  isDarkTheme: isDarkTheme,
                ),
                TabItem(
                  id: '2',
                  title: 'saveVideoTabTwo'.tr,
                  color: AppColors.purple,
                  isDarkTheme: isDarkTheme,
                ),
                TabItem(
                  id: '3',
                  title: 'saveVideoTabThree'.tr,
                  color: AppColors.yellow,
                  isDarkTheme: isDarkTheme,
                ),
              ],
            ),
          ),
          Flexible(
            child: TabBarView(
              physics: const BouncingScrollPhysics(),
              children: <Widget>[
                generalTabContent(),
                locationTabContent(),
                subtitlesTabContent(),
              ],
            ),
          ),
          //const SizedBox(height: 50.0),
        ],
      ),
    );
  }

  Future<void> showSubtitlesDialog() async {
    await showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => AlertDialog(
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'subtitles'.tr,
              ),
              TextButton(
                onPressed: () {
                  // _subtitles is saved in onTapOutside whenever user taps out dialog, this
                  // include when the user taps the save button, so we don't need to
                  // explictly save the text here.
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.green.withValues(alpha: 0.8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'save'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.0,
                  ),
                ),
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              controller: subtitlesTextController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 10,
              style: TextStyle(
                fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.dark,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: isDarkTheme ? Colors.white : Colors.black),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.green),
                ),
              ),
              onTapOutside: (_) => setState(() {
                _subtitles = subtitlesTextController.text.trim();
              }),
            ),
          ],
        ),
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
              autofocus: true,
              controller: customLocationTextController,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                color: ThemeService().isDarkTheme() ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'enterLocation'.tr,
                hintStyle: const TextStyle(
                  color: Colors.white,
                ),
                filled: true,
                fillColor: AppColors.dark,
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.green),
                ),
                enabledBorder: InputBorder.none,
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.green),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (!isGeotaggingEnabled && customLocationTextController.text.isNotEmpty) {
                toggleGeotaggingStatus();
              }
              Navigator.pop(context);
              setState(() {});
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
