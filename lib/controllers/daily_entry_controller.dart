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
  }

  void _checkTodayEntry() {
    final String today = DateFormatUtils.getToday();

    // Checking by date
    if (today != SharedPrefsUtil.getString('today')) {
      SharedPrefsUtil.putString('today', today);
      SharedPrefsUtil.putBool('dailyEntry', false);
      dailyEntry.value = false;
      dailyEntry.refresh();
    }
  }
}
