import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:one_second_diary/main.dart';
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CameraController cameraController;
  //TODO: handle permissions acceptance
  bool acceptedPermissions = true;
  Future<void> initializeCameraController;

  String appPath = '';

  @override
  void initState() {
    super.initState();

    cameraController = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );
    initializeCameraController = cameraController.initialize();

    requestAllPermissions();
  }

  void requestAllPermissions() async {
    if (await requestPermission(Permission.storage)) {
      print('Aceitou permissão storage');
    }
    if (await requestPermission(Permission.camera)) {
      print('Aceitou permissão camera');
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<bool> requestPermission(Permission permission) async {
    if (await permission.isGranted) {
      return true;
    } else {
      var result = await permission.request();
      if (result == PermissionStatus.granted) {
        return true;
      } else {
        return false;
      }
    }
  }

  //call this method from init state to create folder if the folder does not exist
  void createFolder() async {
    try {
      io.Directory directory;
      directory = await getExternalStorageDirectory();
      print('First directory path: ' + directory.path);

      String newPath = '';

      List<String> folders = directory.path.split('/');
      for (int x = 1; x < folders.length; x++) {
        String folder = folders[x];
        if (folder != "Android") {
          newPath += "/" + folder;
        } else {
          break;
        }
      }

      newPath = newPath + "/OneSecondDiary";
      directory = io.Directory(newPath);

      appPath = newPath;

      if (!await directory.exists()) {
        print("Directory does not exist");
        await directory.create(recursive: true);
        print("Directory created");
        print('Final Directory path: ' + directory.path);
      } else {
        print("Directory already exists");
      }
    } catch (e) {
      print('$e');
    }
  }

  Future<void> customStartVideoRecording() async {
    if (!cameraController.value.isInitialized) {
      print('Controller is not initialized');
      return;
    }

    if (cameraController.value.isRecordingVideo) {
      // A recording is already started, do nothing.
      return;
    }

    try {
      await cameraController.startVideoRecording();
    } on CameraException catch (e) {
      print('$e');
      return;
    }
  }

  Future<XFile> customStopVideoRecording() async {
    if (!cameraController.value.isRecordingVideo) {
      return null;
    }

    try {
      return cameraController.stopVideoRecording();
    } on CameraException catch (e) {
      print('$e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
        future: initializeCameraController,
        builder: (context, snapshot) {
          return Scaffold(
            appBar: AppBar(
              leading: Icon(Icons.book),
              title: Text('One Second Diary'),
            ),
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    child: (snapshot.connectionState == ConnectionState.done)
                        ? CameraPreview(cameraController)
                        : CircularProgressIndicator(),
                  ),
                ),
                RaisedButton(
                  child: Text('Gravar'),
                  onPressed: () async {
                    if (acceptedPermissions) {
                      createFolder();
                      print('Open Camera');
                      try {
                        await initializeCameraController;

                        // TODO: need to fix, not literal string
                        String videoPath =
                            '/storage/emulated/0/OneSecondDiary' + '/video.mp4';
                        print('Started Video Recording');
                        setState(() {
                          customStartVideoRecording();
                        });

                        Future.delayed(Duration(seconds: 1), () {
                          setState(() {
                            customStopVideoRecording().then((file) {
                              if (file != null) {
                                print('Video recorded to ${file.path}');
                                file.saveTo(videoPath);
                              }
                            });
                          });
                          print('Stopped Video Recording');
                        });
                      } catch (e) {
                        print('$e');
                      }
                    } else {
                      // Dialog showing the user that the permission needs to be granted
                      print('Rejeitou permissions');
                    }
                  },
                ),
              ],
            ),
          );
        });
  }
}
