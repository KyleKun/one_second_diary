import 'dart:async';
import 'dart:io' as io;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/routes/app_pages.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';
import 'package:one_second_diary/utils/utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class RecordingPage extends StatefulWidget {
  @override
  _RecordingPageState createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController _controller;
  List<CameraDescription> _availableCameras;

  // final tapiocaBalls = [
  //   TapiocaBall.textOverlay("21/02/2021", 100, 10, 100, Colors.red),
  // ];

  bool _isRecording;
  double _recordingProgress;
  // String _appPath;

  @override
  void initState() {
    super.initState();
    _isRecording = false;
    _recordingProgress = 0.0;
    _createFolder();
    _getAvailableCameras();
    // _appPath = StorageUtil.getString('appPath');
  }

  //TODO: probably should move elsewhere
  void _createFolder() async {
    try {
      io.Directory directory;
      directory = await getExternalStorageDirectory();
      //print('First directory path: ' + directory.path);

      String appPath = '';

      List<String> folders = directory.path.split('/');
      for (int i = 1; i < folders.length; i++) {
        String folder = folders[i];
        if (folder != "Android") {
          appPath += "/" + folder;
        } else {
          break;
        }
      }

      appPath = appPath + "/OneSecondDiary";
      directory = io.Directory(appPath);

      StorageUtil.putString('appPath', appPath + '/');
      print('APP PATH\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n' +
          StorageUtil.getString('appPath') +
          '\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\\n');

      if (!await directory.exists()) {
        print("Directory does not exist");
        await directory.create(recursive: true);
        print("Directory created");
        print('Final Directory path: ' + directory.path);
      } else {
        print("Directory already exists");
        //TODO: move to a better place
        List<io.FileSystemEntity> _files;
        _files = directory.listSync(recursive: true, followLinks: false);
        print(_files);
        List<String> allFiles = [];
        for (int i = 0; i < _files.length; i++) {
          String temp = _files[i].toString().split('.').first;
          temp = temp.split('/').last;
          allFiles.add(temp);
        }
        allFiles.sort();
        StorageUtil.putInt('videoCount', allFiles.length);
      }
    } catch (e) {
      print('$e');
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
        // we "finish" downloading here
        if (_recordingProgress.toStringAsFixed(1) == '1.2') {
          _isRecording = false;
          t.cancel();
          _recordingProgress = 0.0;

          print('stop recording');

          stopVideoRecording().then((file) {
            if (file != null) {
              // Crops a little part of the string so ffmpeg will not complain about overriding the file
              // String rotatedVideoPath =
              //     file.path.substring(0, file.path.length - 5);

              // rotatedVideoPath = rotatedVideoPath += '.mp4';

              //String finalPath = _appPath + Utils.getToday() + '.mp4';

              print('Video recorded to ${file.path}');

              //  await executeFFmpeg(
              //       '-i ${file.path} -c copy -metadata:s:v:0 rotate=45 $finalPath');
              // if (io.File(finalPath).existsSync()) {
              //   finalPath =
              //       _appPath + 'DUPLICATED_DAY_' + Utils.getToday() + '.mp4';
              // }

              // var testPath = '/storage/emulated/0/OneSecondDiary/22-2-2021.mp4';

              // file.saveTo(testPath);

              // io.sleep(new Duration(seconds: 5));

              // final cup = Cup(
              //     Content('/storage/emulated/0/OneSecondDiary/22-2-2021.mp4'),
              //     tapiocaBalls);

              // String editedPath = '/storage/emulated/0/OneSecondDiary/cup.mp4';

              // cup.suckUp(editedPath).then((_) {
              //   print("finishProcessing");
              // });

              Get.offNamed(
                Routes.SAVE_VIDEO,
                arguments: file.path,
              );
            } else {
              print('could not record video');
            }
          });
        }
      });
    });
  }

  // void rotateVideo(String videoPath) {
  //   String finalPath = videoPath.replaceAll('.mp4', '-processed.mp4');
  //   executeFFmpeg('-i $videoPath -c copy -metadata:s:v:0 rotate=90 $finalPath');
  // }

  // get available cameras
  Future<void> _getAvailableCameras() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Utils.requestPermission(Permission.camera);
    _availableCameras = await availableCameras();
    _initCamera(_availableCameras.first);
  }

  // init camera
  Future<void> _initCamera(CameraDescription description) async {
    _controller = CameraController(description, ResolutionPreset.veryHigh,
        enableAudio: false);
    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    try {
      await _controller.initialize();
      await _controller.lockCaptureOrientation(DeviceOrientation.landscapeLeft);
    } catch (e) {
      print(e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize.
    if (_controller == null || !_controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller != null) {
        _handleCameraLens(_controller.description, false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _handleCameraLens(var desc, bool toggle) async {
    final lensDirection = desc.lensDirection;

    if (_controller != null) {
      await _controller.dispose();
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
        print('Asked camera not available');
      }
    } else {
      if (desc != null) {
        _initCamera(desc);
      } else {
        print('Asked camera not available');
      }
    }
  }

  Future<void> startVideoRecording() async {
    if (!_controller.value.isInitialized) {
      print('Controller is not initialized');
      return;
    }

    if (_controller.value.isRecordingVideo) {
      // A recording is already started, do nothing.
      return;
    }

    try {
      await _controller.startVideoRecording();
    } on CameraException catch (e) {
      print('$e');
      return;
    }
  }

  Future<XFile> stopVideoRecording() async {
    if (!_controller.value.isRecordingVideo) {
      return null;
    }

    try {
      return _controller.stopVideoRecording();
    } on CameraException catch (e) {
      print('$e');
      return null;
    }
  }

  // int _turnsDeviceOrientation(BuildContext context) {
  //   //
  //   NativeDeviceOrientation orientation =
  //       NativeDeviceOrientationReader.orientation(context);
  //   //
  //   int turns;
  //   switch (orientation) {
  //     case NativeDeviceOrientation.landscapeLeft:
  //       print('\n<\n<\n<\n<\n<\n<\n<\n<\nLAND LEFT\n<\n<\n<\n<\n<\n<\n<\n<\n');
  //       turns = -1;
  //       break;
  //     case NativeDeviceOrientation.landscapeRight:
  //       print('\n>\n>\n>\n>\n>\n>\n>\n>\nLAND RIGHT\n>\n>\n>\n>\n>\n>\n>\n>\n');
  //       turns = -1;
  //       break;
  //     default:
  //       turns = 0;
  //       break;
  //   }

  //   return turns;
  // }

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
        child: Center(child: CameraPreview(_controller)),
      ),

      // child: RotatedBox(
      //
      //   child: Center(
      //     child: ClipRect(
      //       child: AspectRatio(
      //         aspectRatio: _controller.value.aspectRatio,
      //         child: CameraPreview(_controller),
      //       ),
      //     ),
      //   ),
      // ),
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
                  _controller != null &&
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
                          print('change camera');
                          _handleCameraLens(_controller.description, true);
                        }),
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
                          print('go back');
                        }),
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
