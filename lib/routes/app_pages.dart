import 'package:get/get.dart';
import 'package:one_second_diary/bindings/home_binding.dart';
import 'package:one_second_diary/pages/intro/intro_page.dart';
import 'package:one_second_diary/pages/donation/donation_page.dart';
import 'package:one_second_diary/pages/save_video/save_video_page.dart';
import 'package:one_second_diary/pages/recording/recording_page.dart';
import 'package:one_second_diary/pages/home/base/home_page.dart';
part './app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(name: Routes.HOME, page: () => HomePage(), binding: HomeBinding()),
    GetPage(name: Routes.INTRO, page: () => IntroPage()),
    GetPage(name: Routes.RECORDING, page: () => RecordingPage()),
    GetPage(name: Routes.DONATION, page: () => DonationPage()),
    GetPage(name: Routes.SAVE_VIDEO, page: () => SaveVideoPage()),
  ];
}
