import 'package:get/get.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';
import 'package:one_second_diary/utils/utils.dart';
import 'package:permission_handler/permission_handler.dart';

class DayController extends GetxController {
  @override
  void onInit() {
    print('started day controller');
    _getStoragePermission();
    _checkTodayEntry();

    super.onInit();
  }

  var daily = StorageUtil.getBool('dailyEntry').obs;
  var videoCount = StorageUtil.getInt('videoCount').obs ?? 0.obs;

  void updateDaily() {
    daily.value = StorageUtil.getBool('dailyEntry');
    update();
  }

  void updateVideoCount() {
    videoCount.value += 1;
    update();
  }

  void _getStoragePermission() async {
    await Utils.requestPermission(Permission.storage);
  }

  void _checkTodayEntry() {
    final String today = Utils.getToday();

    if (today != StorageUtil.getString('today')) {
      StorageUtil.putString('today', today);
      StorageUtil.putBool('dailyEntry', false);
    } else {
      print('today is not yesterday lol');
    }
  }
}
