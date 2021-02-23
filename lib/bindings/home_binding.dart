import 'package:get/get.dart';
import 'package:one_second_diary/controllers/bottom_app_bar_index_controller.dart';
import 'package:one_second_diary/controllers/day_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DayController>(() => DayController());
    Get.lazyPut<BottomAppBarIndexController>(
        () => BottomAppBarIndexController());
  }
}
