import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_trimmer/video_trimmer.dart';

import '../../controllers/recording_settings_controller.dart';
import '../../enums/video_orientation.dart';
import '../../routes/app_pages.dart';
import '../../utils/clip_trim_policy.dart';
import '../../utils/constants.dart';
import '../../utils/custom_dialog.dart';
import '../../utils/date_format_utils.dart';
import '../../utils/orientation_filter.dart';
import '../../utils/shared_preferences_util.dart';
import '../../utils/storage_utils.dart';
import '../../utils/theme.dart';
import '../../utils/utils.dart';
import '../home/profiles/profiles_page.dart';
import 'widgets/save_button.dart';

class SaveVideoPage extends StatefulWidget {
  @override
  _SaveVideoPageState createState() => _SaveVideoPageState();
}

class _SaveVideoPageState extends State<SaveVideoPage>
    with SingleTickerProviderStateMixin {
  final Map<String, dynamic> routeArguments = Get.arguments;
  final RecordingSettingsController _recordingSettingsController = Get.find();

  late String _tempVideoPath;
  final Trimmer _trimmer = Trimmer();
  late final TabController _tabController;

  final TextEditingController customLocationTextController =
      TextEditingController();
  final TextEditingController subtitlesTextController = TextEditingController();

  late Color pickerColor;
  late Color currentColor;

  final double textOutlineStrokeWidth = 1;

  bool get _outlineEnabled =>
      _recordingSettingsController.isDateOutlineEnabled.value;

  late String _dateFinalFormatValueForVideoEdit;

  late String _dateWrittenValueForVideoEdit;

  List<String> _dateFormatsForVideoEdit = [
    DateFormatUtils.getToday(allowCheckFormattingDayFirst: true),
    DateFormatUtils.getWrittenToday(lang: Get.locale!.languageCode),
  ];

  late bool isTextDate;

  String? _currentAddress;
  Position? _currentPosition;
  bool isGeotaggingEnabled =
      SharedPrefsUtil.getBool('enableGeotagging') ?? false;
  String? _subtitles;
  double _videoStartValue = 0.0;
  double _videoEndValue = 0.0;
  bool _isVideoPlaying = false;
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

    _dateFormatsForVideoEdit = [dateCommonValue, _dateWrittenValueForVideoEdit];
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('locationServicesDisabled'.tr)));
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('locationPermissionDenied'.tr)));
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('locationPermissionPermanentlyDenied'.tr)),
      );
      return false;
    }
    return true;
  }

  Future<void> setGeotagging() async {
    Utils.logInfo('[Geolocation] - Getting location...');
    await _getCurrentPosition().then(
      (_) => SharedPrefsUtil.putBool('enableGeotagging', isGeotaggingEnabled),
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
        )
        .then((Position position) async {
          setState(() => _currentPosition = position);
          await _getAddressFromLatLng(_currentPosition!);
        })
        .catchError((e) {
          Utils.logError('[Geolocation] - Failed to get location: $e');
          if (isGeotaggingEnabled) {
            toggleGeotaggingStatus();
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('locationServiceError'.tr)));
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('locationServiceError'.tr)));
        } else {
          Utils.logError(
            '[Geolocation] - Failed to decode location (attempt $attempts): $e',
          );
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
  }

  static const List<Color> _dateColorSwatches = [
    Colors.white,
    Color(0xff212121),
    AppColors.mainColor,
    Color(0xffE53935),
    AppColors.orange,
    AppColors.yellow,
    Color(0xffFFEB3B),
    AppColors.green,
    Color(0xff26A69A),
    Color(0xff29B6F6),
    Color(0xff3F51B5),
    AppColors.purple,
    Color(0xffEC407A),
    Color(0xff8D6E63),
    Color(0xff9E9E9E),
  ];

  bool _sameColor(Color a, Color b) => a.toARGB32() == b.toARGB32();

  Widget _colorSwatch({
    required Color color,
    required bool selected,
    required VoidCallback onTap,
    Widget? child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.mainColor : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: isDarkTheme ? Colors.white24 : Colors.black12,
            ),
          ),
          child:
              child ??
              (selected
                  ? Icon(Icons.check_rounded, color: invert(color), size: 20)
                  : null),
        ),
      ),
    );
  }

  Future colorPickerDialog() {
    pickerColor = currentColor;
    bool pickerOutline = _outlineEnabled;
    // Colors saved by the old free-form picker may not be one of the
    // swatches; open straight into the custom picker for those.
    bool showCustomPicker = !_dateColorSwatches.any(
      (c) => _sameColor(c, currentColor),
    );

    return _showOptionSheet(
      icon: Icons.palette_rounded,
      color: AppColors.yellow,
      title: 'selectColor'.tr,
      body: StatefulBuilder(
        builder: (context, setSheetState) {
          void pick(Color color) {
            setSheetState(() => pickerColor = color);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preview of the date as it will be burned into the video
              Container(
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.dark,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    if (pickerOutline)
                      Text(
                        _dateFinalFormatValueForVideoEdit,
                        style: TextStyle(
                          fontSize: 20,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = textOutlineStrokeWidth
                            ..color = invert(pickerColor),
                        ),
                      ),
                    Text(
                      _dateFinalFormatValueForVideoEdit,
                      style: TextStyle(fontSize: 20, color: pickerColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final Color color in _dateColorSwatches)
                    _colorSwatch(
                      color: color,
                      selected:
                          !showCustomPicker && _sameColor(color, pickerColor),
                      onTap: () => setSheetState(() {
                        showCustomPicker = false;
                        pickerColor = color;
                      }),
                    ),
                  _colorSwatch(
                    color: _sectionColor,
                    selected: showCustomPicker,
                    onTap: () => setSheetState(
                      () => showCustomPicker = !showCustomPicker,
                    ),
                    child: Icon(
                      Icons.colorize_rounded,
                      size: 20,
                      color: _textColor,
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: showCustomPicker
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: ColorPicker(
                          pickerColor: pickerColor,
                          onColorChanged: pick,
                          enableAlpha: false,
                          labelTypes: const [],
                          portraitOnly: true,
                          colorPickerWidth: 260,
                          pickerAreaHeightPercent: 0.6,
                          pickerAreaBorderRadius: BorderRadius.circular(16),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 16),
              _section(
                onTap: () =>
                    setSheetState(() => pickerOutline = !pickerOutline),
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                child: Row(
                  children: [
                    _iconBadge(Icons.contrast_rounded, AppColors.yellow),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('textOutline'.tr),
                          const SizedBox(height: 2),
                          _sectionSubtitle(
                            'textOutlineHint'.tr,
                            maxLines: null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _styledSwitch(
                      value: pickerOutline,
                      onChanged: (value) =>
                          setSheetState(() => pickerOutline = value),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      primaryLabel: 'done'.tr,
      onPrimary: () {
        setState(() {
          currentColor = pickerColor;
          _recordingSettingsController.setDateOutline(pickerOutline);
        });
        final r = (pickerColor.r * 255.0).round().clamp(0, 255);
        final g = (pickerColor.g * 255.0).round().clamp(0, 255);
        final b = (pickerColor.b * 255.0).round().clamp(0, 255);
        final a = (pickerColor.a * 255.0).round().clamp(0, 255);
        final colorString = '$r,$g,$b,$a';
        _recordingSettingsController.setDateColor(colorString);
        Navigator.of(context).pop();
      },
    );
  }

  /// Shared look for the pop-ups opened from the tab options (date color,
  /// custom location, subtitles): a bottom sheet that rises with the
  /// keyboard, with a header, a body and a full-width primary action.
  Future<void> _showOptionSheet({
    required IconData icon,
    required Color color,
    required String title,
    required Widget body,
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDarkTheme ? AppColors.dark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkTheme ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _iconBadge(icon, color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                body,
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (secondaryLabel != null) ...[
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: _textColor,
                              backgroundColor: _sectionColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: onSecondary,
                            child: Text(
                              secondaryLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: secondaryLabel != null ? 2 : 1,
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mainColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: onPrimary,
                          child: Text(
                            primaryLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _sheetInputDecoration(String hint) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _mutedTextColor),
      filled: true,
      fillColor: _sectionColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: border(Colors.transparent, 1.5),
      focusedBorder: border(AppColors.mainColor, 1.5),
    );
  }

  @override
  void initState() {
    pickerColor = parseColorString(
      _recordingSettingsController.dateColor.value,
    );
    currentColor = pickerColor;
    _tempVideoPath = routeArguments['videoPath'];
    isTextDate = _recordingSettingsController.dateFormatId.value == 1;
    _initCorrectDates();
    _initVideoPlayerController();
    // No indicator animation: the selection (and the content below, see
    // videoProperties) switches the instant a tab is tapped or swiped.
    _tabController = TabController(
      length: 3,
      vsync: this,
      animationDuration: Duration.zero,
    )..addListener(() => setState(() {}));
    if (isGeotaggingEnabled) {
      setGeotagging();
    }
    super.initState();
  }

  @override
  void dispose() {
    _trimmer.videoPlayerController?.dispose();
    _tabController.dispose();
    customLocationTextController.dispose();
    subtitlesTextController.dispose();
    super.dispose();
  }

  void _initVideoPlayerController() {
    _trimmer.loadVideo(videoFile: File(routeArguments['videoPath'])).then((_) {
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

  Future<void> closePopupAndPushToRecording(String cacheVideoPath) async {
    // Deleting video from cache
    StorageUtils.deleteFile(cacheVideoPath);
    _trimmer.videoPlayerController?.dispose();
    Get.back();
    final sdkVersion = SharedPrefsUtil.getInt('sdkVersion');
    final forceNativeCamera =
        SharedPrefsUtil.getBool('forceNativeCamera') ?? false;
    if ((sdkVersion != null && sdkVersion < 29) || forceNativeCamera) {
      Get.offNamed(Routes.HOME);
      final videoFile = await ImagePicker().pickVideo(
        source: ImageSource.camera,
      );
      if (videoFile != null) {
        Get.offNamed(
          Routes.SAVE_VIDEO,
          arguments: {
            'videoPath': videoFile.path,
            'currentDate': DateTime.now(),
            'isFromRecordingPage': true,
          },
        );
      }
    } else {
      Get.offNamed(Routes.RECORDING);
    }
  }

  Color invert(Color color) {
    final r = 255 - (color.r * 255.0).round().clamp(0, 255);
    final g = 255 - (color.g * 255.0).round().clamp(0, 255);
    final b = 255 - (color.b * 255.0).round().clamp(0, 255);

    return Color.fromARGB((color.a * 255.0).round().clamp(0, 255), r, g, b);
  }

  /// Mirrors what OrientationFilter.scaleFilter's crop actually does to a
  /// mismatched clip saved into a portrait profile, so the preview shows
  /// the same framing the saved video will have. VideoViewer (from
  /// video_trimmer) always contain-fits to the source clip's own aspect
  /// ratio regardless of the target canvas — correct for a landscape
  /// profile (which pads, not crops, so nothing is hidden) but wrong for
  /// portrait: a horizontal clip would show letterboxed inside the tall
  /// preview instead of cropped to fill it, the opposite of what actually
  /// gets saved. Used only when [selectedProfileName]'s orientation is
  /// portrait — see _dailyVideoPlayer below.
  Widget _croppedVideoPreview(VideoPlayerController controller) {
    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(backgroundColor: Colors.white),
      );
    }
    final Size videoSize = controller.value.size;
    // FittedBox on its own would size *itself* to fit-contain within
    // whatever space it's given, preserving the child's aspect ratio —
    // `fit` only controls how the child is painted inside that box, not
    // how big the box itself is (see RenderFittedBox.performLayout). Left
    // unconstrained, a wide source video would make FittedBox shrink down
    // to a small landscape-shaped box instead of filling the tall preview
    // — exactly the letterboxing this is meant to avoid. Positioned.fill
    // forces it to actually fill the stack first, so BoxFit.cover has the
    // full area to scale into and crop.
    return Positioned.fill(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: videoSize.width,
          height: videoSize.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  Widget _dailyVideoPlayer() {
    final VideoOrientation orientation = StorageUtils.getOrientation(
      selectedProfileName,
    );
    return ColoredBox(
      color: AppColors.dark,
      // Capped so a portrait profile's taller-than-wide preview can't push
      // the trim viewer and settings below it off-screen — see
      // Constants.previewMaxHeightFraction. Center lets it pillarbox
      // (narrower, not full-width) instead of overflowing.
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height *
                Constants.previewMaxHeightFraction,
          ),
          child: GestureDetector(
            onTap: () => videoPlay(),
            child: AspectRatio(
              // Derived from the selected profile's orientation, not the
              // trimmer/video controller's own reported aspect ratio, so the
              // preview is already the right shape before the video finishes
              // loading — matches selectedProfileName, which is also what
              // "Current profile" above shows and what save_button.dart will
              // actually encode into.
              aspectRatio: OrientationFilter.aspectRatioFor(orientation),
              child: Stack(
                children: [
                  if (orientation == VideoOrientation.portrait)
                    _croppedVideoPreview(_trimmer.videoPlayerController!)
                  else
                    VideoViewer(trimmer: _trimmer),
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
                    alignment: isTextDate
                        ? Alignment.bottomLeft
                        : Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Stack(
                        children: [
                          if (_outlineEnabled)
                            Text(
                              isTextDate
                                  ? _dateFormatsForVideoEdit.last
                                  : _dateFormatsForVideoEdit.first,
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.03,
                                foreground: Paint()
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = textOutlineStrokeWidth
                                  ..color = invert(currentColor),
                              ),
                            ),
                          Text(
                            isTextDate
                                ? _dateFormatsForVideoEdit.last
                                : _dateFormatsForVideoEdit.first,
                            style: TextStyle(
                              fontSize:
                                  MediaQuery.of(context).size.width * 0.03,
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
                            if (_outlineEnabled)
                              Text(
                                customLocationTextController.text.isEmpty
                                    ? _currentAddress ??
                                          customLocationTextController.text
                                    : customLocationTextController.text,
                                style: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width * 0.032,
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
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.032,
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
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) async {
        // Prevent showing the option to re-record video if not coming from the recording page
        final isFromRecordingPage = routeArguments['isFromRecordingPage'];
        if (!isFromRecordingPage) {
          final isExperimentalPicker =
              SharedPrefsUtil.getBool('useExperimentalPicker') ?? true;
          if (!isExperimentalPicker) {
            // Deleting video from cache
            StorageUtils.deleteFile(_tempVideoPath);
          }
          Get.back();
        } else {
          await showDialog(
            barrierDismissible: false,
            context: Get.context!,
            builder: (context) => CustomDialog(
              isDoubleAction: true,
              title: 'discardVideoTitle'.tr,
              content: 'discardVideoDesc'.tr,
              actionText: 'yes'.tr,
              actionColor: AppColors.green,
              action: () async =>
                  await closePopupAndPushToRecording(_tempVideoPath),
              action2Text: 'no'.tr,
              action2Color: Colors.red,
              action2: () => Get.back(),
            ),
          );
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            'saveVideo'.tr,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        // A full-width button pinned under the settings instead of a FAB
        // floating over them (it used to cover the date format options).
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SaveButton(
              isLoading: _isLocationProcessing,
              videoPath: _tempVideoPath,
              videoController: _trimmer.videoPlayerController!,
              dateColor: currentColor,
              dateFormat: _dateFinalFormatValueForVideoEdit,
              isTextDate: isTextDate,
              userPosition: _currentPosition,
              userLocation: customLocationTextController.text.isEmpty
                  ? _currentAddress ?? ''
                  : customLocationTextController.text,
              subtitles: _subtitles,
              videoStartInMilliseconds: _videoStartValue,
              videoEndInMilliseconds: getVideoEndInMilliseconds(),
              videoDuration:
                  _trimmer.videoPlayerController!.value.duration.inSeconds,
              isGeotaggingEnabled: isGeotaggingEnabled,
              textOutlineColor: invert(currentColor),
              textOutlineWidth: _outlineEnabled ? textOutlineStrokeWidth : 0,
              determinedDate: routeArguments['currentDate'],
              isFromRecordingPage: routeArguments['isFromRecordingPage'],
            ),
          ),
        ),
        // The whole page scrolls (not just the tab content) so the options
        // get the room they need instead of scrolling in a thin strip under
        // the video and trimmer.
        body: SingleChildScrollView(
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
                      borderWidth: 2.5,
                      circleSize: 6.0,
                      circleSizeOnDrag: 9.0,
                      circlePaintColor: isDarkTheme
                          ? Colors.white
                          : AppColors.mainColor,
                      borderPaintColor: isDarkTheme
                          ? AppColors.light
                          : AppColors.mainColor.withValues(alpha: 0.75),
                      quickCutIcon: Icons.content_cut_rounded,
                      quickCutIconSize: 18.0,
                      quickCutBackgroundColor: _sectionColor,
                      quickCutForegroundColor: _textColor,
                      quickCutTextColor: _textColor,
                    ),
                    durationStyle: DurationStyle.FORMAT_SS_MS,
                    durationTextStyle: isDarkTheme
                        ? const TextStyle(color: Colors.white)
                        : const TextStyle(color: Colors.black),
                    maxVideoLength: const Duration(milliseconds: 10000),
                    quickCutNumbers: const [1, 1.5, 2, 3, 5, 10],
                    viewerWidth: MediaQuery.of(context).size.width,
                    onChangeStart: (value) => _videoStartValue = value,
                    onChangeEnd: (value) => _videoEndValue = value,
                    onChangePlaybackState: (value) =>
                        setState(() => _isVideoPlaying = value),
                  ),
                ),
              ),
              videoProperties(),
            ],
          ),
        ),
      ),
    );
  }

  Color get _textColor => isDarkTheme ? Colors.white : AppColors.dark;
  Color get _mutedTextColor => isDarkTheme ? Colors.white60 : Colors.black54;
  Color get _sectionColor => isDarkTheme
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.04);

  /// Labels like 'currentProfile' carry their own trailing colon for inline
  /// use elsewhere; drop it where the label sits on its own line.
  String _withoutTrailingColon(String label) =>
      label.replaceFirst(RegExp(r'[\s:\uFF1A]+$'), '');

  Widget _section({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets padding = const EdgeInsets.all(14),
  }) {
    return Material(
      color: _sectionColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }

  Widget _iconBadge(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _textColor,
      ),
    );
  }

  /// [maxLines] null lets the text wrap as far as it needs (for fixed hints
  /// rather than user-entered values).
  Widget _sectionSubtitle(String text, {int? maxLines = 2}) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, height: 1.3, color: _mutedTextColor),
    );
  }

  Switch _styledSwitch({
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : (isDarkTheme ? Colors.white70 : Colors.black45),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.mainColor
            : _sectionColor,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : (isDarkTheme ? Colors.white30 : Colors.black26),
      ),
    );
  }

  void _selectDateFormat(String value) {
    setState(() {
      _dateFinalFormatValueForVideoEdit = value;
      // Place date in the bottom if it is text format
      isTextDate = value != _dateFormatsForVideoEdit.first;

      // Save the date format in shared preferences
      _recordingSettingsController.setDateFormat(isTextDate ? 1 : 0);
    });
  }

  Widget _dateFormatOption(String format, bool selected) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectDateFormat(format),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.mainColor.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.mainColor
                : (isDarkTheme ? Colors.white24 : Colors.black12),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                format,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? AppColors.mainColor : _textColor,
                ),
              ),
            ),
            AnimatedScale(
              scale: selected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.mainColor,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget generalTabContent() {
    final int selectedFormat = _recordingSettingsController.dateFormatId.value;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile
          _section(
            onTap: () {
              Get.to(const ProfilesPage())?.then(
                (_) => setState(() {
                  selectedProfileName = Utils.getCurrentProfile();
                }),
              );
            },
            child: Row(
              children: [
                _iconBadge(Icons.person_rounded, AppColors.mainColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionSubtitle(
                        _withoutTrailingColon('currentProfile'.tr),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedProfileName.isEmpty
                            ? 'default'.tr
                            : selectedProfileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mainColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'change'.tr,
                    style: const TextStyle(
                      color: AppColors.mainColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Date color & format
          _section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _iconBadge(Icons.event_rounded, AppColors.yellow),
                    const SizedBox(width: 12),
                    Expanded(child: _sectionTitle('dateColorAndFormat'.tr)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Tooltip(
                      message: 'selectColor'.tr,
                      child: GestureDetector(
                        onTap: () => colorPickerDialog(),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: currentColor,
                            border: Border.all(
                              color: isDarkTheme
                                  ? Colors.white24
                                  : Colors.black12,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.colorize_rounded,
                            color: invert(currentColor),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        children: [
                          _dateFormatOption(
                            _dateFormatsForVideoEdit.first,
                            selectedFormat == 0,
                          ),
                          const SizedBox(height: 8),
                          _dateFormatOption(
                            _dateFormatsForVideoEdit.last,
                            selectedFormat != 0,
                          ),
                        ],
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

  Future<void> _toggleGeotagging() async {
    if (_isLocationProcessing) return;
    toggleGeotaggingStatus();
    if (isGeotaggingEnabled) {
      await setGeotagging();
    }
    setState(() {});
  }

  Widget locationTabContent() {
    final String? detectedLocation = isGeotaggingEnabled
        ? _currentAddress
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Geotagging
          _section(
            onTap: _toggleGeotagging,
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                _iconBadge(Icons.my_location_rounded, AppColors.purple),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('enableGeotagging'.tr),
                      if (detectedLocation != null &&
                          detectedLocation.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _sectionSubtitle(detectedLocation),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_isLocationProcessing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.mainColor,
                      ),
                    ),
                  )
                else
                  _styledSwitch(
                    value: isGeotaggingEnabled,
                    onChanged: (_) => _toggleGeotagging(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Custom location
          _section(
            onTap: () async {
              await showCustomLocationDialog();
            },
            child: Row(
              children: [
                _iconBadge(Icons.edit_location_alt_rounded, AppColors.purple),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('setCustomLocation'.tr),
                      if (customLocationTextController.text.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _sectionSubtitle(customLocationTextController.text),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: _mutedTextColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget subtitlesTabContent() {
    final String subtitles = subtitlesTextController.text.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: _section(
        onTap: () async => await showSubtitlesDialog(),
        child: Row(
          children: [
            _iconBadge(Icons.subtitles_rounded, AppColors.yellow),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('subtitles'.tr),
                  const SizedBox(height: 4),
                  Text(
                    subtitles.isEmpty ? 'enterSubtitles'.tr : subtitles,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: subtitles.isEmpty ? _mutedTextColor : _textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_rounded, color: _mutedTextColor, size: 26),
          ],
        ),
      ),
    );
  }

  Tab _tab(IconData icon, Color color, String label) {
    return Tab(
      height: 40,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget videoProperties() {
    final List<Widget> tabContents = [
      generalTabContent(),
      locationTabContent(),
      subtitlesTabContent(),
    ];

    return Column(
      children: [
        // Segmented control: all three tabs always fit on screen (the old
        // scrollable tab bar cut "Subtitles" off on narrower phones).
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _sectionColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            splashBorderRadius: BorderRadius.circular(12),
            indicator: BoxDecoration(
              color: isDarkTheme
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isDarkTheme
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            labelColor: _textColor,
            unselectedLabelColor: _mutedTextColor,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            tabs: [
              _tab(
                Icons.tune_rounded,
                AppColors.mainColor,
                'saveVideoTabOne'.tr,
              ),
              _tab(Icons.place_rounded, AppColors.purple, 'saveVideoTabTwo'.tr),
              _tab(
                Icons.subtitles_rounded,
                AppColors.yellow,
                'saveVideoTabThree'.tr,
              ),
            ],
          ),
        ),
        // Swipe left/right on the options to move between tabs, like the
        // TabBarView this replaced.
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final double velocity = details.primaryVelocity ?? 0;
            final int index = _tabController.index;
            if (velocity < -300 && index < _tabController.length - 1) {
              _tabController.animateTo(index + 1);
            } else if (velocity > 300 && index > 0) {
              _tabController.animateTo(index - 1);
            }
          },
          // All three tabs stay built and the stack is as tall as the
          // tallest one, so switching is instant and never changes the
          // page's height (a TabBarView would need a hard-coded height here).
          child: IndexedStack(
            index: _tabController.index,
            alignment: Alignment.topCenter,
            children: tabContents,
          ),
        ),
      ],
    );
  }

  Future<void> showSubtitlesDialog() async {
    await _showOptionSheet(
      icon: Icons.subtitles_rounded,
      color: AppColors.yellow,
      title: 'subtitles'.tr,
      body: TextField(
        autofocus: true,
        controller: subtitlesTextController,
        textCapitalization: TextCapitalization.sentences,
        minLines: 3,
        maxLines: 8,
        style: TextStyle(
          fontFamily: DefaultTextStyle.of(context).style.fontFamily,
          fontSize: 16,
          height: 1.4,
          color: _textColor,
        ),
        cursorColor: AppColors.mainColor,
        decoration: _sheetInputDecoration('enterSubtitles'.tr),
      ),
      secondaryLabel: subtitlesTextController.text.isEmpty ? null : 'reset'.tr,
      onSecondary: () {
        subtitlesTextController.clear();
        Navigator.pop(context);
      },
      primaryLabel: 'save'.tr,
      onPrimary: () => Navigator.pop(context),
    );
    // Commit however the sheet was closed (Save, Reset, back or swipe down)
    // and refresh the subtitles card.
    if (mounted) {
      setState(() {
        _subtitles = subtitlesTextController.text.trim();
      });
    }
  }

  Future<void> showCustomLocationDialog() async {
    await _showOptionSheet(
      icon: Icons.edit_location_alt_rounded,
      color: AppColors.purple,
      title: 'setCustomLocation'.tr.split('(').first.trim(),
      body: TextField(
        autofocus: true,
        controller: customLocationTextController,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        style: TextStyle(fontSize: 16, color: _textColor),
        cursorColor: AppColors.mainColor,
        decoration: _sheetInputDecoration('enterLocation'.tr).copyWith(
          prefixIcon: Icon(Icons.place_outlined, color: _mutedTextColor),
        ),
        onSubmitted: (_) => _confirmCustomLocation(),
      ),
      secondaryLabel: 'reset'.tr,
      onSecondary: () {
        Navigator.pop(context);
        customLocationTextController.clear();
      },
      primaryLabel: 'ok'.tr,
      onPrimary: _confirmCustomLocation,
    );
    if (mounted) setState(() {});
  }

  void _confirmCustomLocation() {
    if (!isGeotaggingEnabled && customLocationTextController.text.isNotEmpty) {
      toggleGeotaggingStatus();
    }
    Navigator.pop(context);
  }

  double getVideoEndInMilliseconds() {
    final bool strictClipLength =
        SharedPrefsUtil.getBool('strictClipLength') ?? false;
    return ClipTrimPolicy.resolveEndMilliseconds(
      selectedEndMilliseconds: _videoEndValue,
      videoDurationMilliseconds:
          _trimmer.videoPlayerController!.value.duration.inMilliseconds,
      strictClipLength: strictClipLength,
    );
  }
}
