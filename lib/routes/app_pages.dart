import 'package:get/get.dart';

import '../bindings/home_binding.dart';
import '../pages/donation/donation_page.dart';
import '../pages/home/base/home_page.dart';
import '../pages/home/create_movie/widgets/create_movie_options.dart';
import '../pages/home/create_movie/widgets/select_video_from_storage.dart';
import '../pages/home/create_movie/widgets/view_movies_page.dart';
import '../pages/home/notification/notification_page.dart';
import '../pages/home/profiles/profiles_page.dart';
import '../pages/home/settings/widgets/preferences_page.dart';
import '../pages/intro/intro_page.dart';
import '../pages/intro/new_features_v152.dart';
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
    GetPage(
      name: Routes.CREATE_MOVIE_OPTIONS,
      page: () => const CreateMovieOptions(),
    ),
    GetPage(
      name: Routes.SELECT_VIDEOS_FROM_STORAGE,
      page: () => const SelectVideoFromStorage(),
    ),
    GetPage(name: Routes.PREFERENCES, page: () => const PreferencesPage()),
    GetPage(name: Routes.PROFILES, page: () => const ProfilesPage()),
    GetPage(name: Routes.NEW_FEATURES_V152, page: () => NewFeaturesV152()),
    GetPage(name: Routes.VIEW_MOVIES, page: () => const ViewMovies()),
  ];
}
