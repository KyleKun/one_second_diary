import 'package:get/get.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';
import 'package:one_second_diary/utils/utils.dart';

class DayController extends GetxController {
  var daily = StorageUtil.getBool('dailyEntry').obs ?? false.obs;

  void updateDaily() {
    daily = StorageUtil.getBool('dailyEntry').obs;
    daily.refresh();
  }
}
