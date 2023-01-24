import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../controllers/recording_settings_controller.dart';
import '../../routes/app_pages.dart';
import '../../utils/constants.dart';
import '../../utils/custom_dialog.dart';
import '../../utils/utils.dart';

// TODO(KyleKun): refactor this in the future ffs lol
class RecordingPage extends StatefulWidget {
  @override
  _RecordingPageState createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final logTag = '[CAMERA] - ';
  late CameraController _cameraController;
  late List<CameraDescription> _availableCameras;

  final RecordingSettingsController _recordingSettingsController = Get.find();

  late bool _isRecording;
  late int _recordingSeconds;

  Timer? _timer;
  int _timerSeconds = 3;
  late bool _isTimerEnable;

  // Zoom properties
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  // Counting pointers (number of user fingers on screen)
  int _pointers = 0;
  int previewQuarterTurns = 0;
  String elapsedSeconds = '00';

  // Create a Stopwatch to track elapsed recording time
  Stopwatch stopwatch = Stopwatch();

  DeviceOrientation currentOrientation = DeviceOrientation.portraitUp;
  DateTime timeOfLastChange = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _isRecording = false;

    _isTimerEnable = _recordingSettingsController.isTimerEnable.value;
    _recordingSeconds = _recordingSettingsController.recordingSeconds.value;

    _getAvailableCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopwatch.stop();
    stopwatch.reset();
    _timer?.cancel();
    _cameraController.dispose();
    super.dispose();
  }

  /// Start countdown timer if it is actived
  void startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
      (Timer timer) {
        if (_timerSeconds == 0) {
          setState(() {
            // Remove  countdown from screen
            _isTimerEnable = false;
            timer.cancel();
          });
          Future.delayed(const Duration(milliseconds: 500), () {
            startVideoRecording();
          });
        } else {
          setState(() {
            _timerSeconds--;
          });
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_cameraController.value.isInitialized) {
        _handleCameraLens(desc: _cameraController.description, toggle: false);
      }
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    // When there are not exactly two fingers on screen don't scale
    if (_pointers != 2) {
      return;
    }

    _currentScale = (_baseScale * details.scale)
        .clamp(_minAvailableZoom, _maxAvailableZoom);

    await _cameraController.setZoomLevel(_currentScale);
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    final _overlayEntry = OverlayEntry(builder: (context) {
      return Positioned(
        left: details.globalPosition.dx,
        top: details.globalPosition.dy,
        child: const Material(
          color: Colors.transparent,
          child: Icon(Icons.brightness_7_rounded),
        ),
      );
    });
    Overlay.of(context).insert(_overlayEntry);
    Future.delayed(const Duration(seconds: 1), _overlayEntry.remove);

    _cameraController.setExposurePoint(offset);
    _cameraController.setFocusPoint(offset);
  }

  Future<void> _getAvailableCameras() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Utils.requestPermission(Permission.camera);
    _availableCameras = await availableCameras();
    _initCamera(_availableCameras.first);
  }

  Future<void> _initCamera(CameraDescription description) async {
    const ResolutionPreset _resolution = ResolutionPreset.veryHigh;
    _cameraController = CameraController(
      description,
      _resolution,
      enableAudio: true,
    );
    _cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    try {
      await _cameraController.initialize();
      await Future.wait([
        _cameraController
            .getMaxZoomLevel()
            .then((value) => _maxAvailableZoom = value),
        _cameraController
            .getMinZoomLevel()
            .then((value) => _minAvailableZoom = value),
      ]);

      await _cameraController
          .lockCaptureOrientation(DeviceOrientation.portraitUp);
    } catch (e) {
      Utils.logError('${logTag}failed to initialize camera: ${e.toString()}');
      showDialog(
        barrierDismissible: false,
        context: Get.context!,
        builder: (context) => CustomDialog(
          isDoubleAction: false,
          title: 'recordingErrorTitle'.tr,
          content: 'tryAgainMsg'.tr,
          actionText: 'Ok',
          actionColor: Colors.red,
          sendLogs: true,
          action: () => Get.back(),
        ),
      );
    }
  }

  void _handleCameraLens({var desc, required bool toggle}) async {
    final lensDirection = desc.lensDirection;

    await _cameraController.dispose();

    if (toggle) {
      CameraDescription newDescription;
      if (lensDirection == CameraLensDirection.front) {
        newDescription = _availableCameras.firstWhere((description) =>
            description.lensDirection == CameraLensDirection.back);
        Utils.logInfo('${logTag}Changed to back camera');
      } else {
        newDescription = _availableCameras.firstWhere((description) =>
            description.lensDirection == CameraLensDirection.front);
        Utils.logInfo('${logTag}Changed to front camera');
      }
      _initCamera(newDescription);
    } else {
      if (desc != null) {
        _initCamera(desc);
      } else {
        Utils.logWarning('${logTag}Asked camera not available');
      }
    }
  }

  void _enableTimer() {
    setState(() {
      _isTimerEnable = true;
    });

    /// Save on SharedPrefs
    _recordingSettingsController.enableTimer();
  }

  void _disableTimer() {
    setState(() {
      _isTimerEnable = false;
    });

    /// Save on SharedPrefs
    _recordingSettingsController.disableTimer();
  }

  void _openRecordingSettings(quarterTurns) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => RotatedBox(
        quarterTurns: quarterTurns,
        child: AlertDialog(
          title: Text('recordingSettings'.tr),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text('seconds'.tr),
                      Obx(
                        () => Text(
                          '${_recordingSettingsController.recordingSeconds}',
                        ),
                      ),
                      Obx(
                        () => SizedBox(
                          width: 150,
                          child: Slider(
                            value: _recordingSettingsController
                                .recordingSeconds.value
                                .toDouble(),
                            min: 1,
                            max: 10,
                            activeColor: AppColors.mainColor.withOpacity(0.9),
                            inactiveColor: AppColors.mainColor.withOpacity(0.2),
                            onChanged: (double value) {
                              _recordingSeconds = value.round();

                              /// Save on SharedPrefs
                              _recordingSettingsController
                                  .setRecordingSeconds(value.round());
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text('timer'.tr),
                      Obx(
                        () => Switch(
                          activeColor: AppColors.mainColor,
                          activeTrackColor:
                              AppColors.mainColor.withOpacity(0.5),
                          value:
                              _recordingSettingsController.isTimerEnable.value,
                          onChanged: (value) {
                            _recordingSettingsController.isTimerEnable.value
                                ? _disableTimer()
                                : _enableTimer();
                          },
                        ),
                      ),
                    ],
                  )
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {});
                Get.back();
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: AppColors.mainColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> startVideoRecording() async {
    Utils.logInfo('${logTag}Started recording video');
    if (!_cameraController.value.isInitialized) {
      Utils.logWarning('${logTag}Controller is not initialized');
      return null;
    }

    if (_cameraController.value.isRecordingVideo) {
      return null;
    }

    try {
      setState(() {
        previewQuarterTurns = getQuarterTurns();
      });
      await _cameraController.lockCaptureOrientation(currentOrientation);

      /// Start video recording with max duration
      final int milliseconds = _recordingSeconds * 1000;

      Utils.logInfo('${logTag}Started recording video with $milliseconds ms');

      stopwatch.start();

      await _cameraController.startVideoRecording();

      // Don't ask me
      Stream.periodic(const Duration(milliseconds: 200)).listen((_) async {
        if (mounted)
          setState(() {
            elapsedSeconds = stopwatch.elapsed.inMilliseconds >= milliseconds &&
                    milliseconds < 10000
                ? '0${milliseconds ~/ 1000}'
                : stopwatch.elapsed.inMilliseconds >= 10000
                    ? '10'
                    : '0${stopwatch.elapsed.inSeconds}';
          });
        if (stopwatch.elapsed.inMilliseconds >= milliseconds + 800) {
          final file = await _cameraController.stopVideoRecording();
          Utils.logInfo('${logTag}Video recorded to ${file.path}');
          setState(() {
            _isRecording = false;
          });
          stopwatch.stop();
          stopwatch.reset();

          Get.offNamed(
            Routes.SAVE_VIDEO,
            arguments: {
              'videoPath': file.path,
              'isFromRecordingPage': true,
              'currentDate': DateTime.now(),
            },
          );
        }
      });
    } on CameraException catch (e) {
      Utils.logError('$logTag${e.toString()}');
      stopwatch.stop();
      stopwatch.reset();
      setState(() {
        _isRecording = false;
      });
      showDialog(
        barrierDismissible: false,
        context: Get.context!,
        builder: (context) => CustomDialog(
          isDoubleAction: false,
          title: 'recordingErrorTitle'.tr,
          content: 'tryAgainMsg'.tr,
          actionText: 'Ok',
          actionColor: Colors.red,
          sendLogs: true,
          action: () => Get.back(),
        ),
      );
      return null;
    }
  }

  BoxDecoration? _screenBorderDecoration() {
    if (_cameraController.value.isRecordingVideo) {
      return BoxDecoration(
        color: Colors.black,
        border: Border.all(
          color: Colors.red,
          style: BorderStyle.solid,
          width: 3,
        ),
      );
    } else {
      return null;
    }
  }

  Widget _addCameraScreen(BuildContext context) {
    return Container(
      decoration: _screenBorderDecoration(),
      child: Center(
        child: Listener(
          onPointerDown: (_) => _pointers++,
          onPointerUp: (_) => _pointers--,
          child: CameraPreview(
            _cameraController,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _handleScaleStart,
                  onScaleUpdate: _handleScaleUpdate,
                  onTapDown: (details) => onViewFinderTap(details, constraints),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          NativeDeviceOrientedWidget(
            useSensor: true,
            fallback: (BuildContext context) {
              setCurrentOrientation(DeviceOrientation.landscapeLeft);
              return cameraPreview(1, _cameraController);
            },
            portraitUp: (context) {
              setCurrentOrientation(DeviceOrientation.portraitUp);
              return cameraPreview(0, _cameraController);
            },
            portraitDown: (context) {
              setCurrentOrientation(DeviceOrientation.portraitDown);
              return cameraPreview(2, _cameraController);
            },
            landscapeLeft: (context) {
              setCurrentOrientation(DeviceOrientation.landscapeLeft);
              return cameraPreview(1, _cameraController);
            },
            landscapeRight: (context) {
              setCurrentOrientation(DeviceOrientation.landscapeRight);
              return cameraPreview(-1, _cameraController);
            },
          ),

          /// Remaining time counter
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Text(
                !_isRecording
                    ? _recordingSeconds >= 10
                        ? '00:10'
                        : '00:0$_recordingSeconds'
                    : '00:$elapsedSeconds',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> setCurrentOrientation(DeviceOrientation orientation) async {
    if (_isRecording) return;
    timeOfLastChange = DateTime.now();
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (DateTime.now().difference(timeOfLastChange).inMilliseconds > 500) {
        if (orientation != currentOrientation) {
          setState(() {
            currentOrientation = orientation;
          });
        }
      }
    });
  }

  Widget cameraPreview(int quarterTurns, CameraController controller) {
    return SafeArea(
      child: Container(
        color: AppColors.dark,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            /// Camera preview
            RotatedBox(
              quarterTurns: previewQuarterTurns,
              child: _addCameraScreen(context),
            ),

            /// Countdown timer
            Opacity(
              opacity: _isTimerEnable ? 1.0 : 0.0,
              child: Align(
                alignment: Alignment.center,
                child: RotatedBox(
                  quarterTurns: quarterTurns,
                  child: Container(
                    height: MediaQuery.of(context).size.width * 0.35,
                    decoration: const BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        /// Avoid showing 0 in countdown
                        _timerSeconds == 0 ? r'\(*v*)/' : '$_timerSeconds',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 56.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            /// Record button
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: ElevatedButton(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.2,
                    height: MediaQuery.of(context).size.width * 0.2,
                    child: Center(
                      child: Icon(
                        Icons.circle,
                        color: !_isRecording ? Colors.red : Colors.grey,
                        size: MediaQuery.of(context).size.width * 0.1,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_isRecording
                        ? Colors.white.withOpacity(0.8)
                        : Colors.grey.withOpacity(0.5),
                    elevation: 8.0,
                    shape: const CircleBorder(),
                  ),
                  onPressed: () {
                    if (!_isRecording) {
                      setState(() {
                        _isRecording = true;
                      });

                      _isTimerEnable ? startTimer() : startVideoRecording();
                    }
                  },
                ),
              ),
            ),

            /// Change camera button
            Positioned(
              right: 15.0,
              bottom: 15.0,
              child: GestureDetector(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !_isRecording
                        ? AppColors.green.withOpacity(0.8)
                        : Colors.grey.withOpacity(0.4),
                  ),
                  width: MediaQuery.of(context).size.width * 0.12,
                  height: MediaQuery.of(context).size.height * 0.12,
                  child: Icon(
                    Icons.cameraswitch,
                    color: Colors.white,
                    size: MediaQuery.of(context).size.width * 0.06,
                  ),
                ),
                onTap: () async {
                  if (!_isRecording) {
                    _handleCameraLens(
                      desc: _cameraController.description,
                      toggle: true,
                    );
                  }
                },
              ),
            ),

            /// Recording settings button
            Positioned(
              left: 15.0,
              bottom: 15.0,
              child: GestureDetector(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !_isRecording
                        ? Colors.blueGrey.withOpacity(0.8)
                        : Colors.grey.withOpacity(0.4),
                  ),
                  width: MediaQuery.of(context).size.width * 0.12,
                  height: MediaQuery.of(context).size.height * 0.12,
                  child: Icon(
                    Icons.settings,
                    color: Colors.white,
                    size: MediaQuery.of(context).size.width * 0.06,
                  ),
                ),
                onTap: () {
                  if (!_isRecording) _openRecordingSettings(quarterTurns);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  int getQuarterTurns() {
    switch (currentOrientation) {
      case DeviceOrientation.portraitUp:
        return 0;
      case DeviceOrientation.landscapeLeft:
        return 1;
      case DeviceOrientation.portraitDown:
        return 2;
      case DeviceOrientation.landscapeRight:
        return -1;
      default:
        return 0;
    }
  }
}
