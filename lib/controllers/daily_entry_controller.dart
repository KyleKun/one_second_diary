import 'package:get/get.dart';

import '../utils/date_format_utils.dart';
import '../utils/notification_service.dart';
import '../utils/shared_preferences_util.dart';

class DailyEntryController extends GetxController {
  @override
  void onInit() {
    _checkTodayEntry();
    super.onInit();
  }

  final dailyEntry = SharedPrefsUtil.getBool('dailyEntry')?.obs ?? false.obs;
  final NotificationService notificationService = Get.find();

  void updateDaily({bool value = true}) {
    SharedPrefsUtil.putBool('dailyEntry', value);
    dailyEntry.value = value;
    dailyEntry.refresh();

    // Remove the existing notification and schedule it again
    notificationService.rescheduleNotification(DateTime.now());
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

    // Remove the existing notification and schedule it again if there is a daily entry
    if(dailyEntry.value)
      notificationService.rescheduleNotification(DateTime.now());
  }
}
