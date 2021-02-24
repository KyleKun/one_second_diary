import 'package:get/get.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';

class VideoCountController extends GetxController {
  final videoCount = StorageUtil.getInt('videoCount').obs;

  void updateVideoCount() {
    StorageUtil.putInt('videoCount', videoCount.value + 1);
    videoCount.value++;
    videoCount.refresh();
  }
}
