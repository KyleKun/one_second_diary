import 'package:get/get.dart';
import '../utils/date_format_utils.dart';
import '../utils/shared_preferences_util.dart';

class DailyEntryController extends GetxController {
  @override
  void onInit() {
    _checkTodayEntry();
    super.onInit();
  }

  final dailyEntry = SharedPrefsUtil.getBool('dailyEntry').obs;

  void updateDaily({bool value = true}) {
    SharedPrefsUtil.putBool('dailyEntry', value);
    dailyEntry.value = value;
    dailyEntry.refresh();
    // Utils().logInfo('DailyEntry set to $value!');
  }

  void _checkTodayEntry() {
    final String today = DateFormatUtils.getToday();

    // Checking by date
    if (today != SharedPrefsUtil.getString('today')) {
      // Utils().logInfo('New Day, DailyEntry was NOT done!');
      SharedPrefsUtil.putString('today', today);
      SharedPrefsUtil.putBool('dailyEntry', false);
      dailyEntry.value = false;
      dailyEntry.refresh();
    } else {
      // dailyEntry.value
      //     ? Utils().logInfo('DailyEntry was already done!')
      //     : Utils().logInfo('DailyEntry was NOT done!');
    }
  }
}
