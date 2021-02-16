import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:one_second_diary/main.dart';
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CameraController cameraController;
  Future<void> initializeCameraController;
  int videoCount = 1;
  String appPath = '';

  final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();

  @override
  void initState() {
    super.initState();

    cameraController = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );
    initializeCameraController = cameraController.initialize();

    requestPermission(Permission.camera);
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

  void createFolder() async {
    try {
      io.Directory directory;
      directory = await getExternalStorageDirectory();
      //print('First directory path: ' + directory.path);

      String newPath = '';

      List<String> folders = directory.path.split('/');
      for (int i = 1; i < folders.length; i++) {
        String folder = folders[i];
        if (folder != "Android") {
          newPath += "/" + folder;
        } else {
          break;
        }
      }

      newPath = newPath + "/OneSecondDiary";
      directory = io.Directory(newPath);

      setState(() {
        appPath = newPath;
      });

      if (!await directory.exists()) {
        print("Directory does not exist");
        await directory.create(recursive: true);
        print("Directory created");
        print('Final Directory path: ' + directory.path);
      } else {
        print("Directory already exists");
        List<io.FileSystemEntity> _files;
        _files = directory.listSync(recursive: true, followLinks: false);
        print(_files);
        List<int> allFiles = [];
        for (int i = 0; i < _files.length; i++) {
          String temp = _files[i].toString().split('.').first;
          temp = temp.split('/').last;
          allFiles.add(int.parse(temp));
        }
        allFiles.sort();
        setState(() {
          videoCount = allFiles.last + 1;
        });
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
                    try {
                      await initializeCameraController;
                      await requestPermission(Permission.storage);
                      createFolder();
                      print('Started Video Recording');
                      setState(() {
                        customStartVideoRecording();
                      });
                      // Probably will need adjustments in the future
                      Future.delayed(Duration(milliseconds: 2 * 1000), () {
                        setState(() {
                          customStopVideoRecording().then((file) {
                            if (file != null) {
                              print('Video recorded to ${file.path}');
                              // var arguments = [
                              //   "-i",
                              //   file.path,
                              //   "-vf",
                              //   "drawtext=",
                              //   "file2.mp4"
                              // ];
                              // _flutterFFmpeg
                              //     .executeWithArguments(arguments)
                              //     .then((rc) => print(
                              //         "FFmpeg process exited with rc $rc"));
                              //'/storage/emulated/0/OneSecondDiary' + '/video.mp4';
                              file.saveTo(appPath + '/$videoCount.mp4');
                              setState(() {
                                videoCount++;
                              });
                            }
                          });
                        });
                        print('Stopped Video Recording');
                      });
                    } catch (e) {
                      print('$e');
                    }
                  },
                ),
              ],
            ),
          );
        });
  }
}
