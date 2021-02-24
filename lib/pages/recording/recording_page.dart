import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/routes/app_pages.dart';
import 'package:one_second_diary/utils/utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class RecordingPage extends StatefulWidget {
  @override
  _RecordingPageState createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController _cameraController;
  List<CameraDescription> _availableCameras;

  bool _isRecording;
  double _recordingProgress;
  // String _appPath;

  @override
  void initState() {
    super.initState();
    _isRecording = false;
    _recordingProgress = 0.0;
    _getAvailableCameras();
    // _appPath = StorageUtil.getString('appPath');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_cameraController != null) {
        _handleCameraLens(desc: _cameraController.description, toggle: false);
      }
    }
  }

  Future<void> _getAvailableCameras() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Utils.requestPermission(Permission.camera);
    _availableCameras = await availableCameras();
    _initCamera(_availableCameras.first);
  }

  Future<void> _initCamera(CameraDescription description) async {
    _cameraController = CameraController(description, ResolutionPreset.veryHigh,
        enableAudio: false);
    _cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    try {
      await _cameraController.initialize();
      await _cameraController
          .lockCaptureOrientation(DeviceOrientation.landscapeLeft);
    } catch (e) {
      Utils().logError(e);
    }
  }

  void _handleCameraLens({var desc, bool toggle}) async {
    final lensDirection = desc.lensDirection;

    if (_cameraController != null) {
      await _cameraController.dispose();
    }

    if (toggle) {
      CameraDescription newDescription;
      if (lensDirection == CameraLensDirection.front) {
        newDescription = _availableCameras.firstWhere((description) =>
            description.lensDirection == CameraLensDirection.back);
      } else {
        newDescription = _availableCameras.firstWhere((description) =>
            description.lensDirection == CameraLensDirection.front);
      }

      if (newDescription != null) {
        _initCamera(newDescription);
      } else {
        Utils().logWarning('Asked camera not available');
      }
    } else {
      if (desc != null) {
        _initCamera(desc);
      } else {
        Utils().logWarning('Asked camera not available');
      }
    }
  }

  void _updateRecordingProgress() {
    setState(() {
      _isRecording = true;
    });
    const oneSec = const Duration(milliseconds: 20);
    new Timer.periodic(oneSec, (Timer t) async {
      setState(() {
        _recordingProgress += 0.01;
        if (_recordingProgress.toStringAsFixed(1) == '1.2') {
          _isRecording = false;
          t.cancel();
          _recordingProgress = 0.0;
          stopVideoRecording().then((file) {
            if (file != null) {
              Utils().logInfo('Video recorded to ${file.path}');

              // if (io.File(finalPath).existsSync()) {
              //   finalPath =
              //       _appPath + 'DUPLICATED_DAY_' + Utils.getToday() + '.mp4';
              // }

              Get.offNamed(
                Routes.SAVE_VIDEO,
                arguments: file.path,
              );
            } else {
              Utils().logError('Could not record video!');
            }
          });
        }
      });
    });
  }

  Future<void> startVideoRecording() async {
    if (!_cameraController.value.isInitialized) {
      Utils().logWarning('Controller is not initialized');
      return;
    }

    if (_cameraController.value.isRecordingVideo) {
      return;
    }

    try {
      await _cameraController.startVideoRecording();
    } on CameraException catch (e) {
      Utils().logError(e);
      return;
    }
  }

  Future<XFile> stopVideoRecording() async {
    if (!_cameraController.value.isRecordingVideo) {
      return null;
    }

    try {
      return _cameraController.stopVideoRecording();
    } on CameraException catch (e) {
      Utils().logError(e);
      return null;
    }
  }

  BoxDecoration _screenBorderDecoration() {
    if (_isRecording) {
      return BoxDecoration(
        color: Colors.black,
        border: Border.all(
          color: Colors.red,
          style: BorderStyle.solid,
          width: 3,
        ),
      );
    } else {
      return BoxDecoration(
        color: Colors.black,
      );
    }
  }

  Widget rotateWarning() {
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Rotate your device to the left'),
        Icon(Icons.rotate_left, size: 56.0),
      ],
    );
  }

  Widget _addCameraScreen(BuildContext context) {
    //
    return RotatedBox(
      quarterTurns: -1, //_turnsDeviceOrientation(context),
      child: Container(
        decoration: _screenBorderDecoration(),
        child: Center(child: CameraPreview(_cameraController)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return Scaffold(
      body: NativeDeviceOrientationReader(
        useSensor: true,
        builder: (BuildContext context) {
          NativeDeviceOrientation orientation =
              NativeDeviceOrientationReader.orientation(context);

          return SafeArea(
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _cameraController != null &&
                          !(orientation !=
                              NativeDeviceOrientation.landscapeLeft)
                      ? _addCameraScreen(context)
                      : rotateWarning(),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.2,
                      height: MediaQuery.of(context).size.height * 0.2,
                      child: RaisedButton(
                        child: Stack(
                          children: [
                            Center(
                              child: Icon(
                                Icons.circle,
                                color: Colors.red,
                                size: 32.0,
                              ),
                            ),
                            Center(
                              child: CircularProgressIndicator(
                                value: _recordingProgress,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.green),
                              ),
                            ),
                          ],
                        ),
                        elevation: 8.0,
                        shape: CircleBorder(),
                        color: Colors.white,
                        onPressed: () {
                          if (!_isRecording) {
                            setState(() {
                              startVideoRecording();
                            });

                            _updateRecordingProgress();
                          }
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    right: 15.0,
                    bottom: 15.0,
                    child: GestureDetector(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                        ),
                        width: MediaQuery.of(context).size.width * 0.12,
                        height: MediaQuery.of(context).size.height * 0.12,
                        child: Icon(
                          Icons.swap_vert,
                          color: Colors.white,
                        ),
                      ),
                      onTap: () {
                        Utils().logInfo('Changed camera');
                        _handleCameraLens(
                          desc: _cameraController.description,
                          toggle: true,
                        );
                      },
                    ),
                  ),
                  Positioned(
                    left: 15.0,
                    bottom: 15.0,
                    child: GestureDetector(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                        ),
                        width: MediaQuery.of(context).size.width * 0.12,
                        height: MediaQuery.of(context).size.height * 0.12,
                        child: Center(
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      onTap: () {
                        Get.offAllNamed(Routes.HOME);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
