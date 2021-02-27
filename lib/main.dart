import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/core_temp.dart';
import 'package:one_second_diary/utils/theme.dart';
import 'lang/translation_service.dart';
import 'routes/app_pages.dart';
import 'utils/shared_preferences_util.dart';
import 'package:device_preview/device_preview.dart';
import 'dart:ui' as ui;

List<CameraDescription> cameras;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //! PROD APP
  await StorageUtil.getInstance();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(
      DevicePreview(
        enabled: false,
        builder: (context) => MyApp(),
      ),
    );
  });

  // //! TEST AREA
  // cameras = await availableCameras();
  // runApp(MaterialApp(home: CoreTemp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      // TODO: option to select language in the settings
      locale: TranslationService.locale,
      fallbackLocale: TranslationService.fallbackLocale,
      translations: TranslationService(),
      getPages: AppPages.pages,
      initialRoute: StorageUtil.getBool('showIntro') == false
          ? Routes.HOME
          : Routes.INTRO,
      debugShowCheckedModeBanner: false,
      title: 'One Second Diary',
      themeMode: ThemeService().theme,
      theme: Themes.light,
      darkTheme: Themes.dark,
    );
  }
}
