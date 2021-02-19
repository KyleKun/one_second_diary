import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:one_second_diary/home_screen.dart';
import 'package:one_second_diary/intro_screen.dart';

List<CameraDescription> cameras;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'One Second Diary',
      theme: ThemeData(
        fontFamily: 'Magic',
        primaryColor: Color(0xffff6366),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: IntroScreen(),
    );
  }
}
