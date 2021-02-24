import 'package:get/get.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';
import 'package:one_second_diary/utils/utils.dart';

class DailyEntryController extends GetxController {
  @override
  void onInit() {
    _checkTodayEntry();

    super.onInit();
  }

  final dailyEntry = StorageUtil.getBool('dailyEntry').obs;

  void updateDaily() {
    StorageUtil.putBool('dailyEntry', true);
    dailyEntry.value = true;
    dailyEntry.refresh();
  }

  void _checkTodayEntry() {
    final String today = Utils.getToday();

    if (today != StorageUtil.getString('today')) {
      StorageUtil.putString('today', today);
      StorageUtil.putBool('dailyEntry', false);
      dailyEntry.value = false;
      dailyEntry.refresh();
    } else {
      Utils().logInfo('DailyEntry was already done!');
    }
  }
}
