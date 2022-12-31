import 'package:get/get.dart';

import '../utils/shared_preferences_util.dart';

class RecordingSettingsController extends GetxController {
  Rx<bool> isTimerEnable = SharedPrefsUtil.getBool('timer')?.obs ?? false.obs;
  Rx<int> recordingSeconds =
      SharedPrefsUtil.getInt('recordingSeconds')?.obs ?? 1.obs;

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
