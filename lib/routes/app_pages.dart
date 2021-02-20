import 'package:get/get.dart';
import 'package:one_second_diary/bindings/home_binding.dart';
import 'package:one_second_diary/intro_screen.dart';
import 'package:one_second_diary/recording_screen.dart';
import '../home_screen.dart';
part './app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(name: Routes.HOME, page: () => HomePage(), binding: HomeBinding()),
    GetPage(name: Routes.INTRO, page: () => IntroPage()),
    GetPage(name: Routes.RECORDING_PAGE, page: () => RecordingPage()),
  ];
}
