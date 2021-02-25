import 'package:get/get.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';

class VideoCountController extends GetxController {
  final videoCount = StorageUtil.getInt('videoCount').obs;

  void updateVideoCount() {
    videoCount.value++;
    videoCount.refresh();
    StorageUtil.putInt('videoCount', videoCount.value);
  }
}
