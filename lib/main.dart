import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:rive/rive.dart';

import 'bindings/initial_binding.dart';
import 'lang/translation_service.dart';
import 'routes/app_pages.dart';
import 'utils/app_paths.dart';
import 'utils/shared_preferences_util.dart';
import 'utils/theme.dart';
import 'utils/video_encoder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RiveNative.init();
  await SharedPrefsUtil.getInstance();

  // Resolved before the first frame: on iOS the container path changes between
  // launches, so nothing may rely on a path persisted by a previous run.
  await AppPaths.init();

  // Probing the ffmpeg build takes one short session, no need to block startup.
  unawaited(VideoEncoder.init());

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      fallbackLocale: TranslationService.fallbackLocale,
      translations: TranslationService(),
      getPages: AppPages.pages,
      initialBinding: InitialBinding(),
      initialRoute: getInitialRoute(),
      debugShowCheckedModeBanner: false,
      title: 'One Second Diary',
      themeMode: ThemeService().theme,
      theme: Themes.light,
      darkTheme: Themes.dark,
    );
  }

  String getInitialRoute() {
    if (SharedPrefsUtil.getBool('showIntro') == false) {
      if (SharedPrefsUtil.getBool('showChangelogV152') == false) {
        return Routes.HOME;
      } else {
        return Routes.NEW_FEATURES_V152;
      }
    } else {
      return Routes.INTRO;
    }
  }
}
