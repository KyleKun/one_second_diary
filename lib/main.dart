import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/home_screen.dart';
import 'package:one_second_diary/intro_screen.dart';

import 'bindings/home_binding.dart';
import 'lang/translation_service.dart';
import 'routes/app_pages.dart';
import 'utils/shared_preferences_util.dart';
import 'utils/utils.dart';

List<CameraDescription> cameras;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StorageUtil.getInstance();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      fallbackLocale: TranslationService.fallbackLocale,
      translations: TranslationService(),
      getPages: AppPages.pages,
      initialBinding: HomeBinding(),
      initialRoute: StorageUtil.getBool('showIntro') == false
          ? Routes.HOME
          : Routes.INTRO,
      debugShowCheckedModeBanner: false,
      title: 'One Second Diary',
      themeMode: ThemeMode.light,
      theme: ThemeData(
        appBarTheme: AppBarTheme(color: Color(0xffff6366)),
        fontFamily: 'Magic',
        primaryColor: Color(0xffff6366),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}
