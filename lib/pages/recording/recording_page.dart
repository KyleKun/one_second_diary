import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timer_builder/timer_builder.dart';

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
    _timer?.cancel();
    _cameraController.dispose();
    super.dispose();
  }

  /// Prevent negative numbers showing up sometimes
  String formatDuration(int remaining) {
    if (remaining <= 0) return '0';
    return remaining.toString();
  }

  /// Start countdown timer if it is actived
  void startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
      (Timer timer) {
        if (_timerSeconds == 0) {
          setState(() {
            // Only to remove countdown from screen since this is a local flag
            _isTimerEnable = false;
            timer.cancel();
          });
          startVideoRecording();
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

    // TODO(KyleKun): this works only in preview for some reason, recording doesn't apply zoom
    await _cameraController.setZoomLevel(_currentScale);
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
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
      if (currentOrientation == DeviceOrientation.landscapeLeft)
        await _cameraController
            .lockCaptureOrientation(DeviceOrientation.landscapeRight);
      else if (currentOrientation == DeviceOrientation.landscapeRight)
        await _cameraController
            .lockCaptureOrientation(DeviceOrientation.landscapeLeft);
      else
        await _cameraController.lockCaptureOrientation(currentOrientation);
    } catch (e) {
      Utils.logError('$logTag${e.toString()}');
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
                              setState(() {
                                _recordingSeconds = value.round();
                              });

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
              onPressed: () => Navigator.pop(context),
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
      /// Listener to save video when max duration reached
      _cameraController
          .onVideoRecordedEvent()
          .listen((VideoRecordedEvent event) {
        try {
          Utils.logInfo('${logTag}Video recorded to ${event.file.path}');
          setState(() {
            _isRecording = false;
          });

          Get.offNamed(
            Routes.SAVE_VIDEO,
            arguments: {
              'videoPath': event.file.path,
              'isFromRecordingPage': true,
              'currentDate': DateTime.now(),
            },
          );
        } catch (e) {
          showDialog(
            barrierDismissible: false,
            context: Get.context!,
            builder: (context) => CustomDialog(
              isDoubleAction: false,
              title: 'recordingErrorTitle'.tr,
              content: 'tryAgainMsg'.tr,
              actionText: 'Ok',
              actionColor: Colors.red,
              action: () => Get.back(),
            ),
          );
        }
      });

      /// Start video recording with max duration
      final int milliseconds =
          _recordingSettingsController.recordingSeconds.value * 1000;
      await _cameraController.startVideoRecording(
        maxVideoDuration: Duration(
          // 400 milliseconds more than selected for 1 second literal, since it's too short
          milliseconds:
              milliseconds == 1000 ? milliseconds + 400 : milliseconds,
        ),
      );
    } on CameraException catch (e) {
      Utils.logError('$logTag${e.toString()}');
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
            child: SizedBox.expand(
              child: CameraPreview(
                _cameraController,
                child: LayoutBuilder(builder:
                    (BuildContext context, BoxConstraints constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _handleScaleStart,
                    onScaleUpdate: _handleScaleUpdate,
                    onTapDown: (details) =>
                        onViewFinderTap(details, constraints),
                  );
                }),
              ),
            )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isRecording && _isTimerEnable
          ? timerPopup(getQuarterTurns())
          : NativeDeviceOrientedWidget(
              useSensor: true,
              fallback: (BuildContext context) {
                lockCameraOrientation(DeviceOrientation.landscapeLeft);
                return cameraPreview(1);
              },
              portraitUp: (context) {
                lockCameraOrientation(DeviceOrientation.portraitUp);
                return cameraPreview(0);
              },
              portraitDown: (context) {
                lockCameraOrientation(DeviceOrientation.portraitDown);
                return cameraPreview(2);
              },
              landscapeLeft: (context) {
                lockCameraOrientation(DeviceOrientation.landscapeLeft);
                return cameraPreview(1);
              },
              landscapeRight: (context) {
                lockCameraOrientation(DeviceOrientation.landscapeRight);
                return cameraPreview(-1);
              },
            ),
    );
  }

  Future<void> lockCameraOrientation(DeviceOrientation orientation) async {
    if (_isRecording) return;
    timeOfLastChange = DateTime.now();
    Future.delayed(const Duration(milliseconds: 200), () async {
      if (DateTime.now().difference(timeOfLastChange).inMilliseconds > 200) {
        if (orientation != currentOrientation) {
          if (orientation == DeviceOrientation.landscapeLeft) {
            await _cameraController
                .lockCaptureOrientation(DeviceOrientation.landscapeRight);
          } else if (orientation == DeviceOrientation.landscapeRight) {
            await _cameraController
                .lockCaptureOrientation(DeviceOrientation.landscapeLeft);
          } else if (orientation == DeviceOrientation.portraitUp) {
            await _cameraController
                .lockCaptureOrientation(DeviceOrientation.portraitUp);
          } else if (orientation == DeviceOrientation.portraitDown) {
            await _cameraController
                .lockCaptureOrientation(DeviceOrientation.portraitDown);
          }

          WidgetsBinding.instance.addPostFrameCallback(
            (_) {
              setState(() {
                currentOrientation = orientation;
              });
            },
          );
        }
      }
    });
  }

  Widget cameraPreview(int quarterTurns) {
    return FutureBuilder(
      future: Future.delayed(
        Duration(
          milliseconds: _isRecording ? 600 : 200,
        ),
        () {},
      ),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return SafeArea(
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  /// Camera preview
                  RotatedBox(
                    quarterTurns: quarterTurns,
                    child: _addCameraScreen(context),
                  ),

                  // /// Countdown timer
                  // Opacity(
                  //   opacity: _isTimerEnable ? 1.0 : 0.0,
                  //   child: Align(
                  //     alignment: Alignment.center,
                  //     child: RotatedBox(
                  //       quarterTurns: 1,
                  //       child: Container(
                  //         height: MediaQuery.of(context).size.width * 0.35,
                  //         decoration: const BoxDecoration(
                  //           color: Colors.black26,
                  //           shape: BoxShape.circle,
                  //         ),
                  //         child: Center(
                  //           child: Text(
                  //             /// Avoid showing 0 in countdown
                  //             _timerSeconds == 0
                  //                 ? r'\(*v*)/'
                  //                 : '$_timerSeconds',
                  //             style: TextStyle(
                  //               color: Colors.white.withOpacity(0.8),
                  //               fontSize: 56.0,
                  //             ),
                  //           ),
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),

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

                            _isTimerEnable
                                ? startTimer()
                                : startVideoRecording();
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
                              ? Colors.green.withOpacity(0.8)
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

                  /// Remaining time counter
                  Align(
                    alignment: quarterTurns % 2 == 0
                        ? Alignment.topCenter
                        : Alignment.centerLeft,
                    child: RotatedBox(
                      quarterTurns: quarterTurns,

                      /// 1.6 seconds instead of 1.0 to prevent some bugs
                      child: TimerBuilder.periodic(
                          const Duration(milliseconds: 1600),
                          alignment: Duration.zero, builder: (context) {
                        final int remaining =
                            _cameraController.value.isRecordingVideo
                                ? _recordingSeconds--
                                : _recordingSeconds;

                        /// Show remaining recording time
                        return Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Text(
                            remaining == 10
                                ? '00:10 '
                                : '00:0${formatDuration(remaining)} ',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  blurRadius: 15.0,
                                  color: Colors.black,
                                  offset: Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          return Center(
            child: RotatedBox(
              quarterTurns: quarterTurns,
              child: Icon(
                _isRecording ? Icons.camera : Icons.hourglass_bottom_rounded,
                color: AppColors.mainColor,
                size: 50.0,
              ),
            ),
          );
        }
      },
    );
  }

  Opacity timerPopup(int quarterTurns) {
    /// Countdown timer
    return Opacity(
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
