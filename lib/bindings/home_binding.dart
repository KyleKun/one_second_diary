import 'package:get/get.dart';
import 'package:one_second_diary/controllers/bottom_app_bar_index_controller.dart';
import 'package:one_second_diary/controllers/daily_entry_controller.dart';
import 'package:one_second_diary/controllers/lang_controller.dart';
// import 'package:one_second_diary/controllers/resolution_controller.dart';
import 'package:one_second_diary/controllers/storage_controller.dart';
import 'package:one_second_diary/controllers/video_count_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<StorageController>(StorageController());
    // Get.put<ResolutionController>(ResolutionController());
    Get.put<LanguageController>(LanguageController());
    Get.put<DailyEntryController>(DailyEntryController());
    Get.put<BottomAppBarIndexController>(BottomAppBarIndexController());
    Get.put<VideoCountController>(VideoCountController());
  }
}
