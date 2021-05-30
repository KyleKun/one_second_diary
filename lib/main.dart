import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'bindings/initial_binding.dart';
import 'lang/translation_service.dart';
import 'routes/app_pages.dart';
import 'utils/shared_preferences_util.dart';
import 'utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefsUtil.getInstance();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(
      MyApp(),
    );
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      fallbackLocale: TranslationService.fallbackLocale,
      translations: TranslationService(),
      getPages: AppPages.pages,
      initialBinding: InitialBinding(),
      initialRoute: SharedPrefsUtil.getBool('showIntro') == false
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
