import 'package:get/get.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';

class VideoCountController extends GetxController {
  final videoCount = StorageUtil.getInt('videoCount').obs;
  final movieCount = StorageUtil.getInt('movieCount').obs;

  void updateVideoCount() {
    videoCount.value++;
    videoCount.refresh();
    StorageUtil.putInt('videoCount', videoCount.value);
  }

  void updateMovieCount() {
    movieCount.value++;
    movieCount.refresh();
    StorageUtil.putInt('movieCount', movieCount.value);
  }

  // Used on refresh button
  void setVideoCount(int count) {
    videoCount.value = count;
    videoCount.refresh();
    StorageUtil.putInt('videoCount', videoCount.value);
  }
}
