import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import 'main.dart';
import 'utils.dart';

class RecordingScreen extends StatefulWidget {
  @override
  _RecordingScreenState createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController _controller;
  List<CameraDescription> _availableCameras;

  @override
  void initState() {
    super.initState();
    Utils.requestPermission(Permission.camera);
    _getAvailableCameras();
  }

  // get available cameras
  Future<void> _getAvailableCameras() async {
    WidgetsFlutterBinding.ensureInitialized();
    _availableCameras = await availableCameras();
    _initCamera(_availableCameras.first);
  }

  // init camera
  Future<void> _initCamera(CameraDescription description) async {
    _controller =
        CameraController(description, ResolutionPreset.max, enableAudio: false);

    try {
      await _controller.initialize();
      // to notify the widgets that camera has been initialized and now camera preview can be done
      setState(() {});
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _toggleCameraLens() {
    // get current lens direction (front / rear)
    final lensDirection = _controller.description.lensDirection;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: _controller != null
                    ? CameraPreview(_controller)
                    : CircularProgressIndicator(),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.2,
                  height: MediaQuery.of(context).size.height * 0.2,
                  child: RaisedButton(
                    elevation: 8.0,
                    shape: CircleBorder(),
                    color: Colors.white,
                    onPressed: () {
                      print('start recording');
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
                        color: Colors.black,
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
                      _toggleCameraLens();
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
                      Navigator.pop(context);
                      print('go back');
                    }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
