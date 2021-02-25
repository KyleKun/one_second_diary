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
    Utils().logInfo('DailyEntry set to TRUE!');
  }

  void _checkTodayEntry() {
    final String today = Utils.getToday();

    final String todayVideoPath =
        StorageUtil.getString('appPath') + today + '.mp4';

    // Checking by file
    if (Utils.checkFileExists(todayVideoPath)) {
      Utils().logInfo('File found, DailyEntry was done!');
      if (!dailyEntry.value) updateDaily();
    } else {
      // Checking by date
      if (today != StorageUtil.getString('today')) {
        Utils().logInfo('New Day, DailyEntry was NOT done!');
        StorageUtil.putString('today', today);
        StorageUtil.putBool('dailyEntry', false);
        dailyEntry.value = false;
        dailyEntry.refresh();
      } else {
        dailyEntry.value
            ? Utils().logInfo('DailyEntry was already done!')
            : Utils().logInfo('DailyEntry was NOT done!');
      }
    }
  }
}
