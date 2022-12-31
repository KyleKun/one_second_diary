import 'package:get/get.dart';

import '../utils/shared_preferences_util.dart';

class VideoCountController extends GetxController {
  final Rx<int> videoCount = SharedPrefsUtil.getInt('videoCount')!.obs;
  final Rx<int> movieCount = SharedPrefsUtil.getInt('movieCount')!.obs;

  void updateVideoCount() {
    videoCount.value++;
    videoCount.refresh();
    SharedPrefsUtil.putInt('videoCount', videoCount.value);
  }

  void updateMovieCount() {
    movieCount.value++;
    movieCount.refresh();
    SharedPrefsUtil.putInt('movieCount', movieCount.value);
  }

  // Used on refresh button
  void setVideoCount(int count) {
    videoCount.value = count;
    videoCount.refresh();
    SharedPrefsUtil.putInt('videoCount', videoCount.value);
  }
}
