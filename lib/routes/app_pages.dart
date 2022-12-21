import 'package:get/get.dart';

import '../bindings/home_binding.dart';
import '../pages/donation/donation_page.dart';
import '../pages/home/base/home_page.dart';
import '../pages/home/create_movie/widgets/create_movie_options.dart';
import '../pages/home/notification/notification_page.dart';
import '../pages/intro/intro_page.dart';
import '../pages/recording/recording_page.dart';
import '../pages/save_video/save_video_page.dart';

part './app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(name: Routes.HOME, page: () => HomePage(), binding: HomeBinding()),
    GetPage(name: Routes.NOTIFICATION, page: () => const NotificationPage()),
    GetPage(name: Routes.INTRO, page: () => IntroPage()),
    GetPage(name: Routes.RECORDING, page: () => RecordingPage()),
    GetPage(name: Routes.DONATION, page: () => DonationPage()),
    GetPage(name: Routes.SAVE_VIDEO, page: () => SaveVideoPage()),
    GetPage(name: Routes.CREATEMOVIEOPTIONS, page: () => const CreateMovieOptions()),
  ];
}
