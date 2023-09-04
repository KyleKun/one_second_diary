import 'package:get/get.dart';

import '../utils/shared_preferences_util.dart';

class VideoCountController extends GetxController {
  final Rx<int> videoCount = SharedPrefsUtil.getInt('videoCount')!.obs;
  final Rx<int> movieCount = SharedPrefsUtil.getInt('movieCount')!.obs;
  final Rx<bool> isProcessing = false.obs;

  void increaseVideoCount() {
    videoCount.value++;
    videoCount.refresh();
    SharedPrefsUtil.putInt('videoCount', videoCount.value);
  }

  void reduceVideoCount() {
    videoCount.value--;
    videoCount.refresh();
    SharedPrefsUtil.putInt('videoCount', videoCount.value);
  }

  void increaseMovieCount() {
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

  void setIsProcessing(bool value) {
    isProcessing.value = value;
    isProcessing.refresh();
  }
}
