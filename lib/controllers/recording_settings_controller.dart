import 'package:get/get.dart';

import '../utils/shared_preferences_util.dart';

class RecordingSettingsController extends GetxController {
  Rx<bool> isTimerEnable = SharedPrefsUtil.getBool('timer')?.obs ?? false.obs;
  Rx<int> recordingSeconds = SharedPrefsUtil.getInt('recordingSeconds')?.clamp(2, 10).obs ?? 2.obs;

  // Edit video page properties
  Rx<String> dateColor = SharedPrefsUtil.getString('dateColor').obs;
  Rx<int> dateFormatId = SharedPrefsUtil.getInt('dateFormatId')?.obs ?? 0.obs;

  void setDateColor(String colorString) {
    dateColor.value = colorString;
    dateColor.refresh();
    SharedPrefsUtil.putString('dateColor', colorString);
  }

  void setDateFormat(int format) {
    dateFormatId.value = format;
    dateFormatId.refresh();
    SharedPrefsUtil.putInt('dateFormatId', format);
  }

  void enableTimer() {
    isTimerEnable.value = true;
    isTimerEnable.refresh();
    SharedPrefsUtil.putBool('timer', true);
  }

  void disableTimer() {
    isTimerEnable.value = false;
    isTimerEnable.refresh();
    SharedPrefsUtil.putBool('timer', false);
  }

  void setRecordingSeconds(int seconds) {
    recordingSeconds.value = seconds;
    recordingSeconds.refresh();
    SharedPrefsUtil.putInt('recordingSeconds', seconds);
  }
}
