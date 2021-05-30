import 'package:get/get.dart';

import '../controllers/bottom_app_bar_index_controller.dart';
import '../controllers/daily_entry_controller.dart';
import '../controllers/lang_controller.dart';
import '../controllers/recording_settings_controller.dart';
import '../controllers/storage_controller.dart';
import '../controllers/video_count_controller.dart';

/// Current Get version has an issue that disposes the controllers after
/// navigating to previous pages, so setting [permanent] to [true] is a
/// workaround to prevent the application from running into this problem
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<StorageController>(
      StorageController(),
      permanent: true,
    );
    Get.put<LanguageController>(
      LanguageController(),
      permanent: true,
    );
    Get.put<DailyEntryController>(
      DailyEntryController(),
      permanent: true,
    );
    Get.put<BottomAppBarIndexController>(
      BottomAppBarIndexController(),
      permanent: true,
    );
    Get.put<VideoCountController>(
      VideoCountController(),
      permanent: true,
    );
    Get.put<RecordingSettingsController>(
      RecordingSettingsController(),
      permanent: true,
    );
  }
}
